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

// MARK: - API Response Models

struct UsageQuota: Decodable {
    /// 0–100 percent
    let utilization: Double
    /// nil when API omits or nulls the field (e.g. immediately after a reset)
    let resetsAt: Date?

    /// 0.0–1.0 for progress bars / stage logic
    var percent: Double { min(utilization / 100.0, 1.0) }

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct OAuthUsageResponse: Decodable {
    let fiveHour: UsageQuota?
    let sevenDay: UsageQuota?
    let sevenDaySonnet: UsageQuota?
    let sevenDayOpus: UsageQuota?

    enum CodingKeys: String, CodingKey {
        case fiveHour       = "five_hour"
        case sevenDay       = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus   = "seven_day_opus"
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
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var dailyUsage: [Date: Int] = [:]
    @Published var isLoadingJournal = false
    @Published var monthlyTokens: Int = 0

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

    /// Status message based on current session utilization
    var petStatusMessage: String {
        sessionMood.headline
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
    private var isInitialized = false           // blocks didSet observers during init
    private let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let minFetchInterval: Double = 60   // never request more than once per minute

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
        isInitialized = true
        startPolling()
        loadJournal()
    }

    deinit { pollTask?.cancel() }

    func loadJournal() {
        isLoadingJournal = true
        Task {
            // Run both heavy file scans concurrently off the main actor
            async let usageTask   = Task.detached(priority: .utility) { JournalLoader.load() }.value
            async let monthlyTask = Task.detached(priority: .utility) { JournalLoader.currentMonthTotal() }.value
            let (usage, monthly) = await (usageTask, monthlyTask)
            dailyUsage    = usage
            monthlyTokens = monthly
            isLoadingJournal = false
        }
    }

    // MARK: - Polling

    func startPolling() {
        pollTask?.cancel()
        pollTask = Task {
            await fetchUsage()
            while !Task.isCancelled {
                let interval = refreshInterval
                guard interval > 0 else { break }
                // Use whichever is larger: user interval or current backoff
                let wait = max(Double(interval), rateLimitBackoff)
                try? await Task.sleep(for: .seconds(wait))
                await fetchUsage()
            }
        }
    }

    func refresh() {
        Task { await fetchUsage() }
    }

    // MARK: - Fetch

    private func fetchUsage() async {
        guard !isFetching else { return }   // prevent concurrent fetches

        // Enforce minimum interval — never hammer the API faster than once per 60s
        let elapsed = Date().timeIntervalSince(lastFetchTime)
        if elapsed < minFetchInterval {
            try? await Task.sleep(for: .seconds(minFetchInterval - elapsed))
        }

        isFetching = true
        defer { isFetching = false }

        guard let token = AuthLoader.loadOAuthToken() else {
            errorMessage = "No OAuth token.\nRun `claude login` in Terminal."
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        lastFetchTime = Date()

        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        var responseData: Data?
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            responseData = data

            guard let http = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }

            switch http.statusCode {
            case 200:
                // Guard against error body disguised as 200 (e.g. rate_limit_error)
                if let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let apiError = raw["error"] as? [String: Any],
                   let msg = apiError["message"] as? String {
                    if fiveHour == nil { errorMessage = msg }
                    break
                }
                let usage = try Self.decode(data)
                applyUsage(usage)
                rateLimitBackoff = 60   // reset backoff on success
            case 401:
                errorMessage = "Token expired.\nRun `claude login` again."
            case 429:
                // Exponential backoff: 60s → 120s → 240s … up to 30min
                rateLimitBackoff = min(rateLimitBackoff * 2, 1800)
                lastFetchTime = Date()  // delay next fetch by backoff duration
                if fiveHour == nil {
                    errorMessage = "Rate limited by API.\nWill retry automatically."
                }
            default:
                errorMessage = "API error \(http.statusCode)"
            }
        } catch let error as DecodingError {
            // JSON shape mismatch — log raw body and surface clearly
            errorMessage = "Unexpected API response.\nCheck app update."
            print("[ClaudePet] Decode error: \(error)")
            if let data = responseData,
               let raw = try? JSONSerialization.jsonObject(with: data) {
                print("[ClaudePet] Raw body: \(raw)")
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func applyUsage(_ usage: OAuthUsageResponse) {
        fiveHour       = usage.fiveHour
        sevenDay       = usage.sevenDay
        sevenDaySonnet = usage.sevenDaySonnet
        sevenDayOpus   = usage.sevenDayOpus
        stage = PetStage(percent: usage.fiveHour?.percent ?? 0)
        checkThresholdNotification()
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

    // MARK: - Decoding

    private nonisolated(unsafe) static let isoFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private nonisolated(unsafe) static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static func decode(_ data: Data) throws -> OAuthUsageResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { dec in
            let str = try dec.singleValueContainer().decode(String.self)
            if let d = isoFrac.date(from: str)  { return d }
            if let d = isoPlain.date(from: str) { return d }
            throw DecodingError.dataCorruptedError(
                in: try dec.singleValueContainer(),
                debugDescription: "Cannot parse date: \(str)"
            )
        }
        return try decoder.decode(OAuthUsageResponse.self, from: data)
    }
}
