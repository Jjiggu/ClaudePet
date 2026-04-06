//
//  PopoverView.swift
//  ClaudePet
//
//  Main popover — Usage / Analytics tabs + pet picker sub-view

import SwiftUI

// MARK: - Tab

private enum Tab { case usage, analytics, pet }
private enum Route { case tabs, characterPicker, settings }

private struct PressableCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Root

struct PopoverView: View {
    @ObservedObject var petManager: PetManager
    @State private var tab: Tab = .usage
    @State private var route: Route = .tabs

    var body: some View {
        Group {
            if route == .characterPicker {
                CharacterPickerView(petManager: petManager) {
                    route = .tabs
                }
            } else if route == .settings {
                SettingsView(petManager: petManager) { route = .tabs }
            } else {
                VStack(spacing: 0) {
                    tabBar
                    Divider()

                    ScrollView {
                        Group {
                            if tab == .usage {
                                MainView(petManager: petManager)
                            } else if tab == .analytics {
                                AnalyticsView(
                                    dailyUsage: petManager.dailyUsage,
                                    isLoading: petManager.isLoadingJournal
                                )
                                .padding(14)
                            } else {
                                PetTabView(petManager: petManager) {
                                    route = .characterPicker
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 360)

                    Divider()
                    bottomBar
                }
            }
        }
        .frame(width: 280)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("Usage",  tab: .usage,     icon: "chart.bar.fill")
            tabButton("Stats",  tab: .analytics, icon: "square.grid.3x3.fill")
            tabButton("Pet",    tab: .pet,       icon: "pawprint.fill")
            Spacer()
            Button { route = .settings } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private func tabButton(_ label: String, tab t: Tab, icon: String) -> some View {
        let isSelected = tab == t
        return Button { tab = t } label: {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 11))
                    Text(label)
                        .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                }
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .padding(.vertical, 7)
                .padding(.horizontal, 8)

                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(height: 2)
                    .cornerRadius(1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom Bar (fixed, all tabs)

    private var bottomBar: some View {
        HStack(spacing: 10) {
            // Reset button
            Button { petManager.refresh() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(petManager.isLoading ? .degrees(360) : .zero)
                        .animation(
                            petManager.isLoading
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: petManager.isLoading
                        )
                        .font(.system(size: 12, weight: .semibold))
                    Text("Reset")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(PressableCapsuleButtonStyle())
            .disabled(petManager.isLoading)

            // Status — right of Reset button
            refreshStatus

            Spacer()

            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    @ViewBuilder
    private var refreshStatus: some View {
        if petManager.isLoading {
            HStack(spacing: 5) {
                ProgressView().controlSize(.small).scaleEffect(0.7)
                Text("Checking...")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        } else if let lastRefreshAt = petManager.lastUsageRefreshAt {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                let seconds = Int(Date().timeIntervalSince(lastRefreshAt))
                HStack(spacing: 5) {
                    Circle()
                        .fill(seconds < 300 ? Color.green : Color.secondary.opacity(0.45))
                        .frame(width: 5, height: 5)
                    Text(shortRelativeTime(from: lastRefreshAt))
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
    }

    private func shortRelativeTime(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        guard seconds >= 60 else { return "Just now" }
        let minutes = seconds / 60
        guard minutes < 60 else { return "\(minutes / 60)h ago" }
        return "\(minutes) min ago"
    }
}

// MARK: - Main (Usage) View

private struct MainView: View {
    @ObservedObject var petManager: PetManager

    private var viewState: UsageViewState {
        petManager.usageViewState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Plan badge
            if let plan = petManager.planName {
                HStack {
                    Text(plan)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.1), in: Capsule())
                    Spacer()
                }
            }

            if let banner = viewState.banner {
                usageBanner(banner)
            }

            if viewState.showsUsageContent {
                usageRow("Session (5h)",  quota: petManager.fiveHour,      color: .blue)
                usageRow("Weekly (7d)",   quota: petManager.sevenDay,       color: .green)
                usageRow("Sonnet Weekly", quota: petManager.sevenDaySonnet, color: .orange)
                usageRow("Opus Weekly",   quota: petManager.sevenDayOpus,   color: .purple)

                if let extra = petManager.extraUsage, extra.isEnabled {
                    Divider()
                    extraUsageRow(extra)
                }
            } else {
                firstLoadPlaceholder
            }
        }
        .padding(14)
    }

    private var firstLoadPlaceholder: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Checking...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func usageBanner(_ banner: UsageBannerState) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: banner.style == .error ? "exclamationmark.triangle.fill" : "arrow.clockwise.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(banner.style == .error ? .orange : .accentColor)

            Text(banner.message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            (banner.style == .error ? Color.orange : Color.accentColor)
                .opacity(0.10),
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    @ViewBuilder
    private func usageRow(_ title: String, quota: UsageQuota?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.caption).fontWeight(.medium)
                Spacer()
                Text(quota.map { "\(Int($0.utilization))%" } ?? "—")
                    .font(.caption2).foregroundColor(.secondary)
            }
            ProgressView(value: quota?.percent ?? 0).tint(color)
            if let resetsAt = quota?.resetsAt {
                Text("Resets \(resetsAt, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
    }

    @ViewBuilder
    private func extraUsageRow(_ extra: ExtraUsage) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Extra Usage")
                    .font(.caption).fontWeight(.medium)
                Spacer()
                Text(String(format: "%.0f%%", extra.percent * 100))
                    .font(.caption2).foregroundColor(.secondary)
            }
            ProgressView(value: extra.percent).tint(.secondary)
            Text(String(format: "$%.2f / $%.2f this month", extra.usedCredits, extra.monthlyLimit))
                .font(.caption2).foregroundColor(.secondary.opacity(0.7))
        }
    }
}

// MARK: - Pet Tab View

private struct PetTabView: View {
    @ObservedObject var petManager: PetManager
    let onOpenCharacterPicker: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Pet display area
            VStack(spacing: 8) {
                AnimatedPetView(
                    stage: petManager.petLevel,
                    size: 96,
                    fps: petManager.animationFPS,
                    fallbackEmoji: petManager.emoji,
                    assetPrefix: petManager.petTabAssetPrefix
                )
                .padding(.top, 16)

                // 무드 뱃지 + 대사
                Text(petManager.sessionMood.badge)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: Capsule())

                Text(petManager.petDialogue)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 220)
            }

            Divider()
                .padding(.vertical, 12)
                .padding(.horizontal, 14)

            // Level + XP bar
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Lv.\(petManager.petLevel)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.7))
                    Spacer()
                    Text("\(Int(petManager.levelProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                ProgressView(value: petManager.levelProgress)
                    .tint(.green)

                if petManager.petLevel < 5 {
                    let remaining = petManager.tokensToNextLevel
                    Text("다음 레벨까지 \(remaining.formatted()) 토큰")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("최고 레벨 달성! 🎉")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)

            Divider()
                .padding(.vertical, 10)
                .padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("세션 컨디션")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    if let session = petManager.fiveHour {
                        Text("\(Int(session.utilization))%")
                            .font(.caption2)
                            .foregroundColor(sessionTint(for: session.percent).opacity(0.8))
                    }
                }

                if let session = petManager.fiveHour {
                    ProgressView(value: session.percent)
                        .tint(sessionTint(for: session.percent))
                } else {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 14)

            Divider()
                .padding(.vertical, 10)
                .padding(.horizontal, 14)

            Button(action: onOpenCharacterPicker) {
                HStack(spacing: 10) {
                    Image(petManager.petType == .seal ? "pet_preview_seal" : "pet_preview_cat")
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .padding(6)
                        .background(
                            petManager.petType == .seal
                                ? Color(red: 0.84, green: 0.92, blue: 1.0)
                                : Color(red: 0.95, green: 0.91, blue: 0.82),
                            in: RoundedRectangle(cornerRadius: 10)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text("캐릭터")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(petManager.petType.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary.opacity(0.75))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)

            Divider()
                .padding(.vertical, 10)
                .padding(.horizontal, 14)

            // Stats
            VStack(spacing: 6) {
                // 오늘 토큰 + 어제 대비
                HStack {
                    Text("✨ 오늘")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    HStack(spacing: 4) {
                        Text("\(petManager.todayTokens.formatted()) 토큰")
                            .font(.caption)
                            .foregroundColor(.primary.opacity(0.75))
                        let delta = petManager.todayTokens - petManager.yesterdayTokens
                        if delta != 0 && petManager.yesterdayTokens > 0 {
                            Text(delta > 0 ? "▲" : "▼")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(delta > 0 ? Color.orange.opacity(0.75) : Color.mint.opacity(0.75))
                            Text(abs(delta).formatted())
                                .font(.caption2)
                                .foregroundColor(delta > 0 ? Color.orange.opacity(0.75) : Color.mint.opacity(0.75))
                        }
                    }
                }
                statRow(icon: "📊", label: "이번달", value: "\(petManager.monthlyTokens.formatted()) 토큰")
                if let resetAt = petManager.fiveHour?.resetsAt {
                    statRow(icon: "⏰", label: "리셋", value: resetAt.formatted(date: .omitted, time: .shortened))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
        }
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack {
            Text(icon + " " + label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.primary.opacity(0.75))
        }
    }

    private func sessionTint(for percent: Double) -> Color {
        switch percent {
        case 0..<0.2: .green
        case 0.2..<0.4: .mint
        case 0.4..<0.6: .yellow
        case 0.6..<0.8: .orange
        default: .red
        }
    }
}

private struct CharacterPickerView: View {
    @ObservedObject var petManager: PetManager
    let onBack: () -> Void

    private let previewOptions: [PetPreviewOption] = [
        .init(
            name: "물범 말랑이",
            subtitle: "보들보들 말랑말랑, 안아줘요 🦭",
            assetName: "pet_preview_seal",
            accent: Color(red: 0.84, green: 0.92, blue: 1.0),
            petType: .seal
        ),
        .init(
            name: "고양 말랑이",
            subtitle: "시크한 척이지만 응원 중이냥 🐾",
            assetName: "pet_preview_cat",
            accent: Color(red: 0.95, green: 0.91, blue: 0.82),
            petType: .cat
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onBack) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("뒤로")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Text("캐릭터")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(previewOptions) { option in
                        PetPreviewRow(
                            option: option,
                            isSelected: petManager.petType == option.petType
                        ) {
                            petManager.petType = option.petType
                            onBack()
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
    }
}

private struct PetPreviewOption: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let assetName: String
    let accent: Color
    let petType: PetType
}

private struct PetPreviewRow: View {
    let option: PetPreviewOption
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(option.assetName)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .padding(6)
                    .background(option.accent, in: RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.8))
                    Text(option.subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: 0)

                Text(isSelected ? "선택됨" : "선택")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.78), in: Capsule())
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [option.accent, Color.white.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.primary.opacity(0.22) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
