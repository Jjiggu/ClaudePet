//
//  UsageViewState.swift
//  ClaudePet
//
//  Pure helpers for deciding whether usage content stays visible and whether a
//  loading or error banner should be shown above it.
//

import Foundation

enum UsageBannerStyle: Equatable {
    case info
    case error
}

struct UsageBannerState: Equatable {
    let style: UsageBannerStyle
    let message: String
}

struct UsageViewState: Equatable {
    let showsUsageContent: Bool
    let banner: UsageBannerState?

    static func resolve(
        hasUsageData: Bool,
        isLoading: Bool,
        errorMessage: String?,
        statusMessage: String?
    ) -> UsageViewState {
        if let errorMessage, !errorMessage.isEmpty {
            return UsageViewState(
                showsUsageContent: hasUsageData,
                banner: UsageBannerState(style: .error, message: errorMessage)
            )
        }

        if let statusMessage, !statusMessage.isEmpty {
            return UsageViewState(
                showsUsageContent: hasUsageData,
                banner: UsageBannerState(style: .info, message: statusMessage)
            )
        }

        if isLoading && hasUsageData {
            return UsageViewState(
                showsUsageContent: true,
                banner: UsageBannerState(style: .info, message: "Checking for newer usage...")
            )
        }

        if isLoading && !hasUsageData {
            return UsageViewState(
                showsUsageContent: false,
                banner: UsageBannerState(style: .info, message: "Loading")
            )
        }

        return UsageViewState(showsUsageContent: hasUsageData, banner: nil)
    }
}
