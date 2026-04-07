//
//  PetManager.swift
//  ClaudePet
//
//  Core logic: OAuth API calls + state management
//  Polling interval: 5 minutes via Task.sleep (suspendable, no Timer)
//
//  Actual API response shape (verified 2026-04-02):
//  {
//    "five_hour":       { "utilization": 87.0, "resets_at": "2026-04-02T16:59:59Z" },
//    "seven_day":       { "utilization": 7.0,  "resets_at": "2026-04-09T05:00:00Z" },
//    "seven_day_sonnet": null,
//    "seven_day_opus":   null,
//  }
//  utilization = 0–100 (percent). No raw used/limit values exposed.

import Foundation
import SwiftUI
import UserNotifications

// MARK: - Pet Type

enum PetType: String, CaseIterable, Identifiable {
    case seal   = "seal"
    case cat    = "cat"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .seal:   "물범 말랑이"
        case .cat:    "고양 말랑이"
        }
    }

    /// 5 stages: 0–20 / 20–40 / 40–60 / 60–80 / 80–100%
    var stages: [String] {
        switch self {
        case .seal:   ["🫧", "🦭", "🦭", "🦭", "🌊"]
        case .cat:    ["😴", "🐱", "😸", "😻", "🙀"]
        }
    }

    /// Representative icon shown in the picker list
    var icon: String { stages[3] }

    func emoji(for stage: PetStage) -> String { stages[stage.rawValue] }
}

// MARK: - Pet Stage

enum PetStage: Int {
    case egg = 0, hatching, chick, mature, overload

    init(percent: Double) {
        switch percent {
        case 0..<0.2:  self = .egg
        case 0.2..<0.4: self = .hatching
        case 0.4..<0.6: self = .chick
        case 0.6..<0.8: self = .mature
        default:        self = .overload
        }
    }
}

enum SessionMood {
    case idle, calm, warmingUp, focused, overloaded

    init(percent: Double) {
        switch percent {
        case 0..<0.01: self = .idle
        case 0..<0.20: self = .calm
        case 0..<0.40: self = .warmingUp
        case 0..<0.60: self = .focused
        default: self = .overloaded
        }
    }

    var badge: String {
        switch self {
        case .idle: "휴식중"
        case .calm: "안정적"
        case .warmingUp: "시동중"
        case .focused: "집중중"
        case .overloaded: "과열직전"
        }
    }

    var headline: String {
        switch self {
        case .idle: "조용히 쉬고 있어요"
        case .calm: "아직은 여유 있어요"
        case .warmingUp: "슬슬 텐션이 올라와요"
        case .focused: "집중해서 달리는 중이에요"
        case .overloaded: "오늘은 정말 빡세게 달렸어요"
        }
    }

    var dialogue: String {
        switch self {
        case .idle: "주인아, 지금은 숨 고르면서 다음 일을 기다리고 있어."
        case .calm: "아직 버틸 만해. 천천히 페이스 올려도 괜찮아."
        case .warmingUp: "손이 풀리기 시작했어. 이제 일할 맛 좀 나는데?"
        case .focused: "나 지금 완전 몰입했어. 이 흐름 끊기면 아쉬울지도."
        case .overloaded: "헉, 오늘 나 진짜 많이 뛰었어. 잠깐 쉬게 해주면 금방 회복할게."
        }
    }

    var hint: String {
        switch self {
        case .idle: "여유 있을 때 다음 세션 준비를 해두면 좋아요."
        case .calm: "아직 안전 구간이에요. 긴 작업 시작하기 좋은 타이밍이에요."
        case .warmingUp: "속도가 붙는 구간이에요. 중요한 작업 우선순위를 정리해보세요."
        case .focused: "사용량이 빠르게 올라갈 수 있어요. 리셋 시간도 함께 보는 게 좋아요."
        case .overloaded: "과열 구간이에요. 다음 세션 전까지 잠깐 쉬거나 모델 사용 계획을 조정해보세요."
        }
    }
}

// MARK: - PetManager

@MainActor
final class PetManager: ObservableObject {
    @Published var stage: PetStage = .egg
    @Published var fiveHour: UsageQuota?
    @Published var sevenDay: UsageQuota?
    @Published var sevenDaySonnet: UsageQuota?
    @Published var sevenDayOpus: UsageQuota?
    @Published var extraUsage: ExtraUsage?
    @Published var isLoading = false
    @Published private(set) var lastUsageRefreshAt: Date?
    @Published var errorMessage: String?
    @Published var dailyUsage: [Date: Int] = [:]
    @Published var isLoadingJournal = false
    @Published var monthlyTokens: Int = 0
    @Published private(set) var authState: AuthState = .missing
    @Published private(set) var planName: String?
    @Published private(set) var isUsingCachedUsage = false
    @Published private(set) var usageStatusMessage: String?
    @Published private(set) var nextUsageRetryAt: Date?

    @Published var petType: PetType {
        didSet { UserDefaults.standard.set(petType.rawValue, forKey: "selectedPetType") }
    }

    /// What to show in the menu bar: image only / usage only / both
    enum MenuBarDisplayMode: String, CaseIterable {
        case imageOnly  = "imageOnly"
        case usageOnly  = "usageOnly"
        case both       = "both"

        var label: String {
            switch self {
            case .imageOnly: "Icon only"
            case .usageOnly: "Usage only"
            case .both:      "Both"
            }
        }
    }

    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet { UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode") }
    }

    /// Auto-refresh interval in seconds. 0 = Off.
    @Published var refreshInterval: Int {
        didSet {
            guard isInitialized else { return }  // skip during init (didSet fires on @Published assignment)
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
            startPolling()
        }
    }

    /// Whether to send a local notification when usage crosses the threshold.
    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
            if notificationsEnabled { requestNotificationPermission() }
        }
    }

    /// 0.0–1.0. Notification fires when fiveHour utilization ≥ this value.
    @Published var notificationThreshold: Double {
        didSet { UserDefaults.standard.set(notificationThreshold, forKey: "notificationThreshold") }
    }

    /// Current emoji based on stage + selected pet type
    var emoji: String { petType.emoji(for: stage) }
    
    var menuBarAssetPrefix: String? {
        switch petType {
        case .seal: "pet_stage1"
        case .cat: "pet_cat_menu"
        }
    }
    
    var petTabAssetPrefix: String? {
        switch petType {
        case .seal: "pet_stage1_large"
        case .cat: "pet_cat_large"
        }
    }

    // MARK: - Pet Level (monthly JSONL tokens, resets on the 1st)

    /// Level 1–5 based on this month's token usage
    var petLevel: Int {
        switch monthlyTokens {
        case 0..<500_000:            return 1
        case 500_000..<2_000_000:    return 2
        case 2_000_000..<5_000_000:  return 3
        case 5_000_000..<10_000_000: return 4
        default:                     return 5
        }
    }

    private static let levelThresholds = [0, 500_000, 2_000_000, 5_000_000, 10_000_000]

    /// 0.0–1.0 progress within the current level
    var levelProgress: Double {
        let lv = petLevel - 1
        if lv >= 4 { return 1.0 }
        let lo = Self.levelThresholds[lv]
        let hi = Self.levelThresholds[lv + 1]
        return min(Double(monthlyTokens - lo) / Double(hi - lo), 1.0)
    }

    /// Tokens remaining until next level (0 at max level)
    var tokensToNextLevel: Int {
        let lv = petLevel - 1
        guard lv < 4 else { return 0 }
        return max(Self.levelThresholds[lv + 1] - monthlyTokens, 0)
    }

    /// Today's token count from JSONL
    var todayTokens: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return dailyUsage[today] ?? 0
    }

    /// Yesterday's token count from JSONL
    var yesterdayTokens: Int {
        let today = Calendar.current.startOfDay(for: Date())
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today) else { return 0 }
        return dailyUsage[yesterday] ?? 0
    }

    var sessionMood: SessionMood {
        SessionMood(percent: fiveHour?.percent ?? 0)
    }

    var petDialogue: String {
        sessionMood.dialogue
    }

    var petCareHint: String {
        sessionMood.hint
    }

    var sessionUsageSummary: String {
        guard let fiveHour else { return "세션 데이터를 불러오는 중이에요." }
        let percent = Int(fiveHour.utilization.rounded())
        return "최근 5시간 세션 사용량은 \(percent)%예요."
    }

    var hasUsageData: Bool {
        fiveHour != nil
            || sevenDay != nil
            || sevenDaySonnet != nil
            || sevenDayOpus != nil
            || extraUsage != nil
    }

    var usageViewState: UsageViewState {
        UsageViewState.resolve(
            hasUsageData: hasUsageData,
            isLoading: isLoading,
            errorMessage: errorMessage,
            statusMessage: usageStatusBannerMessage
        )
    }

    private var usageStatusBannerMessage: String? {
        if let usageStatusMessage {
            return usageStatusMessage
        }

        guard isUsingCachedUsage, hasUsageData else { return nil }
        return "Showing cached usage from the last successful check."
    }

    var authSourceDisplayName: String {
        authState.source?.displayName ?? "없음"
    }

    var isAuthenticated: Bool {
        authState.token != nil
    }

    /// Animation fps: 4 (idle) → 15 (max session). RunCat-style speed.
    var animationFPS: Double {
        let p = fiveHour?.percent ?? 0
        return 4.0 + 11.0 * p
    }

    private var pollTask: Task<Void, Never>?
    private var isFetching = false              // guard against concurrent fetches
    private var didSendThresholdAlert = false
    private var rateLimitBackoff: Double = 60   // seconds; doubles on each 429, resets on success
    private var lastFetchTime: Date = .distantPast  // minimum 60s between requests
    private var lastPlanFetchTime: Date = .distantPast
    private var isInitialized = false           // blocks didSet observers during init
    private let usageClient = UsageAPIClient()
    private let usageSnapshotCache = UsageSnapshotCache()
    private let minFetchInterval: Double = 60   // never request more than once per minute
    private let planCacheTTL: TimeInterval = 24 * 60 * 60

    private enum UsageFetchResult {
        case sentRequest
        case skippedCooldown(TimeInterval)
        case skippedInFlight
        case skippedMissingAuth
    }

    private static let lastUsageFetchAttemptAtKey = "lastUsageFetchAttemptAt"
    private static let rateLimitBackoffKey = "rateLimitBackoff"
    private static let cachedPlanNameKey = "cachedPlanName"
    private static let lastPlanFetchAtKey = "lastPlanFetchAt"

    init() {
        let saved = UserDefaults.standard.string(forKey: "selectedPetType") ?? ""
        petType = PetType(rawValue: saved) ?? .seal
        let savedMode = UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? ""
        menuBarDisplayMode = MenuBarDisplayMode(rawValue: savedMode) ?? .both
        // NOTE: @Published didSet fires during init — isInitialized flag prevents
        // startPolling() from being called twice (once from didSet, once explicitly below).
        refreshInterval = UserDefaults.standard.object(forKey: "refreshInterval") as? Int ?? 300
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        notificationThreshold = UserDefaults.standard.object(forKey: "notificationThreshold") as? Double ?? 0.8
        lastFetchTime = UserDefaults.standard.object(forKey: Self.lastUsageFetchAttemptAtKey) as? Date ?? .distantPast
        rateLimitBackoff = UserDefaults.standard.object(forKey: Self.rateLimitBackoffKey) as? Double ?? 60
        planName = UserDefaults.standard.string(forKey: Self.cachedPlanNameKey)
        lastPlanFetchTime = UserDefaults.standard.object(forKey: Self.lastPlanFetchAtKey) as? Date ?? .distantPast
        hydrateUsageFromCache()
        isInitialized = true
        refreshAuthStatus()
        startPolling()
        loadJournal()
        fetchPlanInfo()
    }

    deinit { pollTask?.cancel() }

    func refreshAuthStatus() {
        authState = AuthLoader.loadAuthState()
    }

    func fetchPlanInfo() {
        guard Date().timeIntervalSince(lastPlanFetchTime) >= planCacheTTL else { return }
        guard let token = authState.token else { return }
        Task {
            let fetchStartedAt = Date()
            defer {
                lastPlanFetchTime = fetchStartedAt
                UserDefaults.standard.set(fetchStartedAt, forKey: Self.lastPlanFetchAtKey)
            }

            do {
                if let rawPlan = try await usageClient.fetchPlanName(token: token) {
                    let formattedPlanName = formatPlanName(rawPlan)
                    planName = formattedPlanName
                    UserDefaults.standard.set(formattedPlanName, forKey: Self.cachedPlanNameKey)
                    persistCurrentUsageSnapshot()
                }
            } catch {
                print("[ClaudePet] account endpoint unavailable or failed")
            }
        }
    }

    private func formatPlanName(_ raw: String) -> String {
        switch raw.lowercased() {
        case let s where s.contains("max_20"): return "Claude Max 20×"
        case let s where s.contains("max_5"):  return "Claude Max 5×"
        case let s where s.contains("max"):    return "Claude Max"
        case let s where s.contains("pro"):    return "Claude Pro"
        default: return raw
        }
    }

    func loadJournal() {
        isLoadingJournal = true
        Task {
            let snapshot = await Task.detached(priority: .utility) {
                JournalLoader.loadSnapshot()
            }.value
            dailyUsage = snapshot.dailyUsage
            monthlyTokens = snapshot.monthlyTokens
            isLoadingJournal = false
        }
    }

    // MARK: - Polling

    func startPolling() {
        pollTask?.cancel()
        guard refreshInterval > 0 else { return }
        pollTask = Task {
            while !Task.isCancelled {
                let result = await fetchUsage()
                let interval = refreshInterval
                guard interval > 0 else { break }
                let wait: TimeInterval
                if case .skippedCooldown(let remaining) = result {
                    wait = max(remaining, 1)
                } else {
                    // Use whichever is larger: user interval or current backoff
                    wait = max(Double(interval), rateLimitBackoff)
                }
                try? await Task.sleep(for: .seconds(wait))
            }
        }
    }

    func refresh() {
        Task { await fetchUsage() }
    }

    // MARK: - Fetch

    private func fetchUsage() async -> UsageFetchResult {
        guard !isFetching else { return .skippedInFlight }   // prevent concurrent fetches

        let cooldownRemaining = usageFetchCooldownRemaining()
        guard cooldownRemaining <= 0 else {
            rememberRetryWindow(seconds: cooldownRemaining)
            if hasUsageData {
                usageStatusMessage = "Showing last usage while waiting to retry.\(retryHint())"
            }
            return .skippedCooldown(cooldownRemaining)
        }

        isFetching = true
        defer {
            isFetching = false
            isLoading = false
        }

        let currentAuthState = AuthLoader.loadAuthState()
        authState = currentAuthState

        guard let token = currentAuthState.token else {
            errorMessage = "No OAuth token.\nRun `claude login` in Terminal."
            return .skippedMissingAuth
        }

        isLoading = true
        errorMessage = nil
        usageStatusMessage = nil
        nextUsageRetryAt = nil
        recordUsageFetchAttempt(at: Date())

        do {
            let usage = try await usageClient.fetchUsage(token: token)
            let refreshedAt = Date()
            applyUsage(usage)
            lastUsageRefreshAt = refreshedAt
            isUsingCachedUsage = false
            usageStatusMessage = nil
            nextUsageRetryAt = nil
            persistUsageSnapshot(usage, fetchedAt: refreshedAt)
            updateRateLimitBackoff(60)
        } catch UsageAPIClientError.payloadMessage(let message) {
            errorMessage = hasUsageData
                ? "Couldn’t refresh usage. Showing last saved data.\n\(message)"
                : message
        } catch UsageAPIClientError.unauthorized {
            errorMessage = hasUsageData
                ? "Token expired. Showing cached usage.\nRun `claude login` again."
                : "Token expired.\nRun `claude login` again."
        } catch UsageAPIClientError.rateLimited {
            let newBackoff = min(rateLimitBackoff * 2, 1800)
            updateRateLimitBackoff(newBackoff)
            let attemptAt = Date()
            recordUsageFetchAttempt(at: attemptAt)
            rememberRetryWindow(from: attemptAt)
            if fiveHour == nil {
                errorMessage = "Rate limited by API.\nWill retry automatically."
            } else {
                usageStatusMessage = "Rate limited by API. Showing cached usage.\(retryHint())"
            }
        } catch UsageAPIClientError.api(let statusCode) {
            errorMessage = hasUsageData
                ? "API error \(statusCode). Showing last saved data."
                : "API error \(statusCode)"
        } catch UsageAPIClientError.decoding(let error, let rawBody) {
            errorMessage = hasUsageData
                ? "Unexpected API response. Showing last saved data.\nCheck app update."
                : "Unexpected API response.\nCheck app update."
            print("[ClaudePet] Decode error: \(error)")
            if let rawBody {
                print("[ClaudePet] Raw body: \(rawBody)")
            }
        } catch UsageAPIClientError.invalidResponse {
            errorMessage = hasUsageData
                ? "Unexpected API response. Showing last saved data.\nCheck app update."
                : "Unexpected API response.\nCheck app update."
        } catch {
            if let urlError = error as? URLError, urlError.code == .userAuthenticationRequired {
                errorMessage = hasUsageData
                    ? "Token expired. Showing cached usage.\nRun `claude login` again."
                    : "Token expired.\nRun `claude login` again."
            } else {
                errorMessage = hasUsageData
                    ? "Couldn’t refresh usage. Showing last saved data.\n\(error.localizedDescription)"
                    : error.localizedDescription
            }
        }

        return .sentRequest
    }

    private func usageFetchCooldownRemaining(now: Date = Date()) -> TimeInterval {
        guard lastFetchTime != .distantPast else { return 0 }
        let cooldown = max(minFetchInterval, rateLimitBackoff)
        return max(lastFetchTime.addingTimeInterval(cooldown).timeIntervalSince(now), 0)
    }

    private func recordUsageFetchAttempt(at date: Date) {
        lastFetchTime = date
        UserDefaults.standard.set(date, forKey: Self.lastUsageFetchAttemptAtKey)
    }

    private func updateRateLimitBackoff(_ seconds: TimeInterval) {
        rateLimitBackoff = seconds
        UserDefaults.standard.set(seconds, forKey: Self.rateLimitBackoffKey)
    }

    private func rememberRetryWindow(from attemptAt: Date? = nil, seconds: TimeInterval? = nil) {
        let base = attemptAt ?? Date()
        let wait = seconds ?? max(minFetchInterval, rateLimitBackoff)
        nextUsageRetryAt = base.addingTimeInterval(max(wait, 1))
    }

    private func retryHint() -> String {
        guard let nextUsageRetryAt else { return "" }
        let seconds = max(Int(nextUsageRetryAt.timeIntervalSinceNow.rounded(.up)), 0)
        if seconds < 60 {
            return " Next retry in \(seconds)s."
        }
        let minutes = Int(ceil(Double(seconds) / 60.0))
        return " Next retry in \(minutes) min."
    }

    private func hydrateUsageFromCache() {
        guard let snapshot = usageSnapshotCache.load() else { return }
        applyUsage(snapshot.usage, shouldNotify: false)
        lastUsageRefreshAt = snapshot.fetchedAt
        isUsingCachedUsage = true
        usageStatusMessage = nil

        if planName == nil {
            planName = snapshot.planName
        }
    }

    private func persistCurrentUsageSnapshot() {
        guard let usage = currentUsageResponse, let lastUsageRefreshAt else { return }
        persistUsageSnapshot(usage, fetchedAt: lastUsageRefreshAt)
    }

    private func persistUsageSnapshot(_ usage: OAuthUsageResponse, fetchedAt: Date) {
        do {
            try usageSnapshotCache.save(
                CachedUsageSnapshot(
                    fetchedAt: fetchedAt,
                    usage: usage,
                    planName: planName
                )
            )
        } catch {
            print("[ClaudePet] Failed to persist usage cache: \(error.localizedDescription)")
        }
    }

    private var currentUsageResponse: OAuthUsageResponse? {
        guard hasUsageData else { return nil }
        return OAuthUsageResponse(
            fiveHour: fiveHour,
            sevenDay: sevenDay,
            sevenDaySonnet: sevenDaySonnet,
            sevenDayOpus: sevenDayOpus,
            extraUsage: extraUsage
        )
    }

    private func applyUsage(_ usage: OAuthUsageResponse, shouldNotify: Bool = true) {
        fiveHour       = usage.fiveHour
        sevenDay       = usage.sevenDay
        sevenDaySonnet = usage.sevenDaySonnet
        sevenDayOpus   = usage.sevenDayOpus
        extraUsage     = usage.extraUsage
        stage = PetStage(percent: usage.fiveHour?.percent ?? 0)
        if shouldNotify {
            checkThresholdNotification()
        }
    }

    private func checkThresholdNotification() {
        guard notificationsEnabled else { return }
        let util = fiveHour?.percent ?? 0
        if util >= notificationThreshold && !didSendThresholdAlert {
            didSendThresholdAlert = true
            let content = UNMutableNotificationContent()
            content.title = "ClaudePet 사용량 경고"
            content.body = "세션 사용량이 \(Int(util * 100))%에 도달했습니다."
            content.sound = .default
            let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(req)
        } else if util < notificationThreshold * 0.9 {
            didSendThresholdAlert = false // reset after usage drops
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
