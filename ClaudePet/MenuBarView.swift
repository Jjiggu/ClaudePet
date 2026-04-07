//
//  MenuBarView.swift
//  ClaudePet
//
//  Status bar label: animated pixel-art pet + session %
//  Animation speed scales with session usage (RunCat style).

import SwiftUI

struct MenuBarView: View {
    @ObservedObject var petManager: PetManager

    private var statusSummary: String {
        if let errorMessage = petManager.errorMessage, !petManager.hasUsageData {
            return errorMessage.replacingOccurrences(of: "\n", with: " ")
        }

        if let session = petManager.fiveHour {
            let base = "\(petManager.petType.displayName), session usage \(Int(session.utilization))%"
            if let errorMessage = petManager.errorMessage {
                return "\(base). \(errorMessage.replacingOccurrences(of: "\n", with: " "))"
            }
            if petManager.isUsingCachedUsage {
                return "\(base). Showing cached usage"
            }
            return base
        }

        return "Checking Claude usage"
    }

    var body: some View {
        HStack(spacing: 4) {
            if petManager.errorMessage != nil && !petManager.hasUsageData {
                Text("⚠️").font(.system(size: 13))
            } else {
                let mode = petManager.menuBarDisplayMode
                if mode == .imageOnly || mode == .both {
                    AnimatedPetView(
                        stage: petManager.petLevel,
                        size: 30,
                        fps: 8,
                        fallbackEmoji: petManager.emoji,
                        assetPrefix: petManager.menuBarAssetPrefix,
                        useTemplateRendering: true
                    )
                }
                if (mode == .usageOnly || mode == .both), let session = petManager.fiveHour {
                    Text("\(Int(session.utilization))%")
                        .font(.system(size: 11))
                }
            }
        }
        .help(statusSummary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(statusSummary)
    }
}
