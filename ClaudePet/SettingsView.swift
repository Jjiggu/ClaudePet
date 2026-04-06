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
        ("Off", 0), ("1m", 60), ("2m", 120), ("5m", 300), ("10m", 600)
    ]

    private var selectedIntervalLabel: String {
        intervalOptions.first(where: { $0.seconds == petManager.refreshInterval })?.label ?? "Custom"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                        Text("Back").font(.system(size: 13))
                    }
                    .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Settings")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("Back").font(.system(size: 13)).opacity(0)
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
        .onAppear {
            petManager.refreshAuthStatus()
        }
    }

    // MARK: - Auth Section

    private var authSection: some View {
        settingsCard {
            Text("Authentication")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(petManager.isAuthenticated ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text(petManager.isAuthenticated ? "Connected" : "Not connected")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 6))

                Spacer()

                Text(petManager.authSourceDisplayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !petManager.isAuthenticated {
                Text("Run `claude login` in Terminal.")
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
        MenuBarView(petManager: petManager)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
    }

    // MARK: - Auto Refresh Section

    private var refreshSection: some View {
        settingsCard {
            Text("Auto Refresh")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            HStack {
                Text("Current")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Menu {
                    ForEach(intervalOptions, id: \.seconds) { option in
                        Button {
                            petManager.refreshInterval = option.seconds
                        } label: {
                            if petManager.refreshInterval == option.seconds {
                                Label(option.label, systemImage: "checkmark")
                            } else {
                                Text(option.label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(selectedIntervalLabel)
                            .font(.caption)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.07), in: Capsule())
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
        }
    }

    // MARK: - Notification Section

    private var notificationSection: some View {
        settingsCard {
            Text("Notifications")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Toggle(isOn: $petManager.notificationsEnabled) {
                Text("Usage alert")
                    .font(.caption)
            }
            .toggleStyle(.switch)

            if petManager.notificationsEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Alert at \(Int(petManager.notificationThreshold * 100))%+")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int((1 - petManager.notificationThreshold) * 100))% left")
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
