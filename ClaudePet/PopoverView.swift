//
//  PopoverView.swift
//  ClaudePet
//
//  Main popover — Usage / Analytics tabs + pet picker sub-view

import SwiftUI

// MARK: - Tab

private enum Tab { case usage, analytics, pet }

// MARK: - Root

struct PopoverView: View {
    @ObservedObject var petManager: PetManager
    @State private var tab: Tab = .usage
    @State private var showCharacterPicker = false
    @State private var showSettings = false

    var body: some View {
        Group {
            if showCharacterPicker {
                CharacterPickerView {
                    showCharacterPicker = false
                }
            } else if showSettings {
                SettingsView(petManager: petManager) { showSettings = false }
            } else {
                VStack(spacing: 0) {
                    tabBar
                    Divider()
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
                            showCharacterPicker = true
                        }
                    }
                }
            }
        }
        .frame(width: 280)
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            tabButton("사용량", tab: .usage,     icon: "chart.bar.fill")
            tabButton("활동",   tab: .analytics,  icon: "square.grid.3x3.fill")
            tabButton("펫",     tab: .pet,        icon: "pawprint.fill")
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func tabButton(_ label: String, tab t: Tab, icon: String) -> some View {
        Button { tab = t } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(tab == t ? .primary : .secondary)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                tab == t
                    ? Color.primary.opacity(0.1)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Main (Usage) View

private struct MainView: View {
    @ObservedObject var petManager: PetManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let error = petManager.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            } else {
                usageRow("Session (5h)",  quota: petManager.fiveHour,      color: .blue)
                usageRow("Weekly (7d)",   quota: petManager.sevenDay,       color: .green)
                usageRow("Sonnet Weekly", quota: petManager.sevenDaySonnet, color: .orange)
                usageRow("Opus Weekly",   quota: petManager.sevenDayOpus,   color: .purple)

                if let nextReset = [petManager.fiveHour?.resetsAt,
                                    petManager.sevenDay?.resetsAt]
                    .compactMap({ $0 }).min() {
                    Divider()
                    HStack {
                        Image(systemName: "clock").foregroundColor(.secondary)
                        Text("Session resets \(nextReset, style: .relative)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            // Bottom bar: refresh (left) + quit (right)
            HStack {
                Button { petManager.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(petManager.isLoading ? .degrees(360) : .zero)
                        .animation(
                            petManager.isLoading
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: petManager.isLoading
                        )
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(petManager.isLoading)

                Spacer()

                Button { NSApplication.shared.terminate(nil) } label: {
                    Image(systemName: "power")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
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
            VStack(spacing: 6) {
                AnimatedPetView(
                    stage: petManager.petLevel,
                    size: 96,
                    fps: petManager.animationFPS,
                    fallbackEmoji: petManager.emoji,
                    assetPrefix: "pet_stage1_large"
                )
                .padding(.top, 16)

                Text(petManager.sessionMood.badge)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.08), in: Capsule())

                Text(petManager.petStatusMessage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Text(petManager.petDialogue)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
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
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.primary)
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

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("세션 컨디션")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(petManager.sessionUsageSummary)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                if let session = petManager.fiveHour {
                    ProgressView(value: session.percent)
                        .tint(sessionTint(for: session.percent))
                } else {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(petManager.petCareHint)
                    .font(.caption2)
                    .foregroundColor(.secondary)
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
                    Image("pet_preview_seal")
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .padding(6)
                        .background(Color(red: 0.84, green: 0.92, blue: 1.0), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("캐릭터")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("물범 말랑이와 예시 캐릭터 보기")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
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
                statRow(icon: "✨", label: "오늘", value: "\(petManager.todayTokens.formatted()) tokens")
                statRow(icon: "📊", label: "이번달", value: "\(petManager.monthlyTokens.formatted()) tokens")
                if let resetAt = petManager.fiveHour?.resetsAt {
                    statRow(icon: "⏰", label: "리셋", value: resetAt.formatted(date: .omitted, time: .shortened))
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 16)
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
                .foregroundColor(.primary)
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
    let onBack: () -> Void

    private let previewOptions: [PetPreviewOption] = [
        .init(
            name: "물범 말랑이",
            subtitle: "현재 사용 중",
            assetName: "pet_preview_seal",
            accent: Color(red: 0.84, green: 0.92, blue: 1.0),
            status: .active
        ),
        .init(
            name: "햄말랑",
            subtitle: "예시 캐릭터",
            assetName: "pet_preview_hamster",
            accent: Color(red: 0.99, green: 0.9, blue: 0.76),
            status: .preview
        ),
        .init(
            name: "토끼 말랑이",
            subtitle: "예시 캐릭터",
            assetName: "pet_preview_bunny",
            accent: Color(red: 0.96, green: 0.93, blue: 1.0),
            status: .preview
        ),
        .init(
            name: "병아리 말랑이",
            subtitle: "예시 캐릭터",
            assetName: "pet_preview_chick",
            accent: Color(red: 1.0, green: 0.95, blue: 0.76),
            status: .preview
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
                        PetPreviewRow(option: option)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
    }
}

private struct PetPreviewOption: Identifiable {
    enum Status {
        case active
        case preview

        var label: String {
            switch self {
            case .active: "현재"
            case .preview: "예시"
            }
        }
    }

    let id = UUID()
    let name: String
    let subtitle: String
    let assetName: String
    let accent: Color
    let status: Status
}

private struct PetPreviewRow: View {
    let option: PetPreviewOption

    var body: some View {
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
                    .foregroundColor(.primary)
                Text(option.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)

            HStack {
                Text(option.status.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.78), in: Capsule())
            }
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
                .stroke(option.status == .active ? Color.primary.opacity(0.18) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}
