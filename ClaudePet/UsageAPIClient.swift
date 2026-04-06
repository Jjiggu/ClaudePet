//
//  UsageAPIClient.swift
//  ClaudePet
//
//  Isolates the OAuth usage/account API request and decoding behavior so
//  PetManager can focus on state transitions and view-facing logic.
//

import Foundation

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

struct ExtraUsage: Decodable {
    let isEnabled: Bool
    /// Spending limit in dollars (e.g. 2000 = $2,000)
    let monthlyLimit: Double
    /// Amount spent so far this month in dollars
    let usedCredits: Double
    /// 0–100 percent; nil when nothing has been spent yet
    let utilization: Double?

    var percent: Double { min((utilization ?? 0) / 100.0, 1.0) }

    enum CodingKeys: String, CodingKey {
        case isEnabled    = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits  = "used_credits"
        case utilization
    }
}

struct OAuthUsageResponse: Decodable {
    let fiveHour: UsageQuota?
    let sevenDay: UsageQuota?
    let sevenDaySonnet: UsageQuota?
    let sevenDayOpus: UsageQuota?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour       = "five_hour"
        case sevenDay       = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus   = "seven_day_opus"
        case extraUsage     = "extra_usage"
    }
}

enum UsageAPIClientError: Error {
    case invalidResponse
    case payloadMessage(String)
    case unauthorized
    case rateLimited
    case api(statusCode: Int)
    case decoding(DecodingError, rawBody: String?)
}

struct UsageAPIClient {
    private let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private let accountEndpoint = URL(string: "https://api.anthropic.com/api/account")!

    func fetchUsage(token: String) async throws -> OAuthUsageResponse {
        let request = authorizedRequest(url: endpoint, token: token)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw UsageAPIClientError.invalidResponse
        }

        switch http.statusCode {
        case 200:
            if let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let apiError = raw["error"] as? [String: Any],
               let message = apiError["message"] as? String {
                throw UsageAPIClientError.payloadMessage(message)
            }

            do {
                return try Self.decodeUsage(data)
            } catch let error as DecodingError {
                throw UsageAPIClientError.decoding(error, rawBody: String(data: data, encoding: .utf8))
            }
        case 401:
            throw UsageAPIClientError.unauthorized
        case 429:
            throw UsageAPIClientError.rateLimited
        default:
            throw UsageAPIClientError.api(statusCode: http.statusCode)
        }
    }

    func fetchPlanName(token: String) async throws -> String? {
        let request = authorizedRequest(url: accountEndpoint, token: token)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw UsageAPIClientError.invalidResponse
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UsageAPIClientError.invalidResponse
        }

        return json["subscription_plan"] as? String
            ?? json["plan"] as? String
            ?? json["plan_name"] as? String
            ?? json["tier"] as? String
    }

    private func authorizedRequest(url: URL, token: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        return request
    }

    private nonisolated(unsafe) static let isoFrac: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private nonisolated(unsafe) static let isoPlain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func decodeUsage(_ data: Data) throws -> OAuthUsageResponse {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            if let date = isoFrac.date(from: rawValue) { return date }
            if let date = isoPlain.date(from: rawValue) { return date }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot parse date: \(rawValue)"
            )
        }

        return try decoder.decode(OAuthUsageResponse.self, from: data)
    }
}
