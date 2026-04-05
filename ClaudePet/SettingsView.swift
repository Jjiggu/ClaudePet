//
//  SettingsView.swift
//  ClaudePet
//
//  Settings: Authentication status, Auto-refresh interval, Notification threshold

import SwiftUI

struct SettingsView: View {
    @ObservedObject var petManager: PetManager
    let onBack: () -> Void

    private let intervalOptions: [(label: String, seconds: Int)] = [
        ("Off", 0), ("1분", 60), ("2분", 120), ("5분", 300), ("10분", 600)
    ]

    // Auth state evaluated once per view render (cheap)
    private var authSource: String? { AuthLoader.authSource() }
    private var isConnected: Bool { authSource != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                        Text("뒤로").font(.system(size: 13))
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("설정")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                // Invisible balance for centering
                Text("뒤로").font(.system(size: 13)).opacity(0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider()

            VStack(spacing: 10) {
                authSection
                refreshSection
                notificationSection
                menuBarSection
            }
            .padding(14)
        }
    }

    // MARK: - Auth Section

    private var authSection: some View {
        settingsCard {
            Text("인증")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text(isConnected ? "연결됨" : "연결 안 됨")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))

                Spacer()

                Text(authSource ?? "없음")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !isConnected {
                Text("터미널에서 `claude login`을 실행하세요.")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Menu Bar Display Section

    private var menuBarSection: some View {
        settingsCard {
            Text("Menu bar")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Picker("", selection: $petManager.menuBarDisplayMode) {
                ForEach(PetManager.MenuBarDisplayMode.allCases, id: \.self) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            menuBarPreview
        }
    }

    @ViewBuilder
    private var menuBarPreview: some View {
        let mode = petManager.menuBarDisplayMode
        HStack(spacing: 4) {
            if mode == .imageOnly || mode == .both {
                Image("pet_stage1_0")
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 22, height: 22)
            }
            if mode == .usageOnly || mode == .both {
                Text(petManager.fiveHour.map { "\(Int($0.utilization))%" } ?? "0%")
                    .font(.system(size: 11))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - Auto Refresh Section

    private var refreshSection: some View {
        settingsCard {
            Text("자동 새로고침")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Picker("", selection: $petManager.refreshInterval) {
                ForEach(intervalOptions, id: \.seconds) { opt in
                    Text(opt.label).tag(opt.seconds)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        settingsCard {
            Text("알림")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Toggle(isOn: $petManager.notificationsEnabled) {
                Text("사용량 경고 알림")
                    .font(.caption)
            }
            .toggleStyle(.switch)

            if petManager.notificationsEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("경고 기준: \(Int(petManager.notificationThreshold * 100))% 이상")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("(\(Int((1 - petManager.notificationThreshold) * 100))% 남음)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: $petManager.notificationThreshold,
                        in: 0.5...0.95,
                        step: 0.05
                    )
                    .tint(.green)
                }
            }
        }
    }

    // MARK: - Card Helper

    @ViewBuilder
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }
}
