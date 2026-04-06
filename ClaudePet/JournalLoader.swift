//
//  JournalLoader.swift
//  ClaudePet
//
//  Scans ~/.claude/projects/**/*.jsonl and aggregates token usage by day.
//
//  Record shape (assistant type):
//  {
//    "type": "assistant",
//    "timestamp": "2026-04-01T10:00:00.000Z",
//    "message": {
//      "usage": {
//        "input_tokens": 100,
//        "output_tokens": 200,
//        "cache_creation_input_tokens": 50,
//        "cache_read_input_tokens": 30
//      }
//    }
//  }

import Foundation

struct JournalSnapshot {
    let dailyUsage: [Date: Int]
    let monthlyTokens: Int

    static let empty = JournalSnapshot(dailyUsage: [:], monthlyTokens: 0)
}

struct JournalLoader {

    /// Returns { startOfDay → totalTokens } for the last `days` calendar days.
    static func load(days: Int = 35, now: Date = Date(), baseURL: URL? = nil) -> [Date: Int] {
        loadSnapshot(days: days, now: now, baseURL: baseURL).dailyUsage
    }

    /// Returns both the recent daily usage map and the current-month total in one filesystem scan.
    static func loadSnapshot(days: Int = 35, now: Date = Date(), baseURL: URL? = nil) -> JournalSnapshot {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        guard let cutoff = cal.date(byAdding: .day, value: -(days - 1), to: today) else {
            return .empty
        }
        guard let monthStart = startOfCurrentMonth(for: now, calendar: cal) else {
            return .empty
        }

        let base = baseURL ?? defaultProjectsURL()

        guard let enumerator = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return .empty }

        var dailyUsage: [Date: Int] = [:]
        var monthlyTokens = 0
        let earliestRelevantDate = min(cutoff, monthStart)

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }

            // Skip files not touched in either window (cheap pre-filter)
            if let mod = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               mod < earliestRelevantDate { continue }

            parseFile(
                url,
                cutoff: cutoff,
                monthStart: monthStart,
                calendar: cal,
                into: &dailyUsage,
                monthlyTotal: &monthlyTokens
            )
        }

        return JournalSnapshot(dailyUsage: dailyUsage, monthlyTokens: monthlyTokens)
    }

    /// Returns total tokens for the current calendar month (resets on the 1st).
    static func currentMonthTotal(now: Date = Date(), baseURL: URL? = nil) -> Int {
        loadSnapshot(now: now, baseURL: baseURL).monthlyTokens
    }

    // MARK: - File parsing

    private static func parseFile(
        _ url: URL,
        cutoff: Date,
        monthStart: Date,
        calendar cal: Calendar,
        into result: inout [Date: Int],
        monthlyTotal: inout Int
    ) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let record = record(from: String(line)) else { continue }

            if record.date >= cutoff {
                let day = cal.startOfDay(for: record.date)
                result[day, default: 0] += record.tokens
            }

            if record.date >= monthStart {
                monthlyTotal += record.tokens
            }
        }
    }

    private static func defaultProjectsURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")
    }

    private static func startOfCurrentMonth(for now: Date, calendar cal: Calendar) -> Date? {
        var comps = cal.dateComponents([.year, .month], from: now)
        comps.day = 1
        comps.hour = 0
        comps.minute = 0
        comps.second = 0
        return cal.date(from: comps)
    }

    static func record(from line: String) -> (date: Date, tokens: Int)? {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              json["type"] as? String == "assistant",
              let tsStr = json["timestamp"] as? String,
              let date = parseDate(tsStr),
              let message = json["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any]
        else { return nil }

        let tokens = tokenCount(from: usage)
        guard tokens > 0 else { return nil }
        return (date, tokens)
    }

    static func tokenCount(from usage: [String: Any]) -> Int {
        (usage["input_tokens"]                as? Int ?? 0)
        + (usage["output_tokens"]               as? Int ?? 0)
        + (usage["cache_creation_input_tokens"] as? Int ?? 0)
        + (usage["cache_read_input_tokens"]     as? Int ?? 0)
    }

    // MARK: - Date parsing

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

    private static func parseDate(_ str: String) -> Date? {
        isoFrac.date(from: str) ?? isoPlain.date(from: str)
    }
}
