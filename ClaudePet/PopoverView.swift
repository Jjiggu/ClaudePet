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
    @State private var showPicker = false
    @State private var showSettings = false

    var body: some View {
        Group {
            if showPicker {
                PetPickerView(petManager: petManager) { showPicker = false }
            } else if showSettings {
                SettingsView(petManager: petManager) { showSettings = false }
            } else {
                VStack(spacing: 0) {
                    tabBar
                    Divider()
                    if tab == .usage {
                        MainView(petManager: petManager) { showPicker = true }
                    } else if tab == .analytics {
                        AnalyticsView(
                            dailyUsage: petManager.dailyUsage,
                            isLoading: petManager.isLoadingJournal
                        )
                        .padding(14)
                    } else {
                        PetTabView(petManager: petManager)
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
    let onOpenPicker: () -> Void

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

            // Pet picker row
            Button(action: onOpenPicker) {
                HStack {
                    Text("말랑이")
                        .font(.caption).foregroundColor(.primary)
                    Spacer()
                    Text(petManager.petType.displayName)
                        .font(.caption).foregroundColor(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

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

// MARK: - Pet Picker View

private struct PetPickerView: View {
    @ObservedObject var petManager: PetManager
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
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

            // Section header
            Text("기본 말랑이")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 6)

            // List
            VStack(spacing: 0) {
                ForEach(Array(PetType.allCases.enumerated()), id: \.element.id) { index, type in
                    petRow(type)
                    if index < PetType.allCases.count - 1 {
                        Divider().padding(.leading, 30)
                    }
                }
            }
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 14)

            Spacer(minLength: 14)
        }
    }

    @ViewBuilder
    private func petRow(_ type: PetType) -> some View {
        let isSelected = petManager.petType == type
        Button { petManager.petType = type } label: {
            HStack(spacing: 10) {
                Circle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 8, height: 8)

                Text(type.displayName)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)

                Spacer()

                // Stage preview: show all 5 stages small
                HStack(spacing: 1) {
                    ForEach(Array(type.stages.enumerated()), id: \.offset) { _, emoji in
                        Text(emoji).font(.system(size: 13))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Pet Tab View

private struct PetTabView: View {
    @ObservedObject var petManager: PetManager

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

                Text(petManager.petStatusMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
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

            // Stats
            VStack(spacing: 6) {
                statRow(icon: "✨", label: "오늘", value: "\(petManager.todayTokens.formatted()) tokens")
                statRow(icon: "📊", label: "이번달", value: "\(petManager.monthlyTokens.formatted()) tokens")
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
}
