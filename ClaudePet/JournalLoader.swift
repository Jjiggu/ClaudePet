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

struct JournalLoader {

    /// Returns { startOfDay → totalTokens } for the last `days` calendar days.
    static func load(days: Int = 35) -> [Date: Int] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard let cutoff = cal.date(byAdding: .day, value: -(days - 1), to: today) else {
            return [:]
        }

        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        guard let enumerator = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [:] }

        var result: [Date: Int] = [:]

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }

            // Skip files not touched in the window (cheap pre-filter)
            if let mod = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               mod < cutoff { continue }

            parseFile(url, cutoff: cutoff, calendar: cal, into: &result)
        }

        return result
    }

    /// Returns total tokens for the current calendar month (resets on the 1st).
    static func currentMonthTotal() -> Int {
        let cal = Calendar.current
        let now = Date()
        var comps = cal.dateComponents([.year, .month], from: now)
        comps.day = 1
        comps.hour = 0; comps.minute = 0; comps.second = 0
        guard let monthStart = cal.date(from: comps) else { return 0 }

        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        guard let enumerator = FileManager.default.enumerator(
            at: base,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total = 0
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            // Pre-filter: skip files not modified this month
            if let mod = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
               mod < monthStart { continue }

            guard let content = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                guard let data = String(line).data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      json["type"] as? String == "assistant",
                      let tsStr = json["timestamp"] as? String,
                      let date = parseDate(tsStr),
                      date >= monthStart,
                      let message = json["message"] as? [String: Any],
                      let usage = message["usage"] as? [String: Any]
                else { continue }
                total += (usage["input_tokens"]                as? Int ?? 0)
                       + (usage["output_tokens"]               as? Int ?? 0)
                       + (usage["cache_creation_input_tokens"] as? Int ?? 0)
                       + (usage["cache_read_input_tokens"]     as? Int ?? 0)
            }
        }
        return total
    }

    // MARK: - File parsing

    private static func parseFile(
        _ url: URL,
        cutoff: Date,
        calendar cal: Calendar,
        into result: inout [Date: Int]
    ) {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return }

        for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let data = String(line).data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["type"] as? String == "assistant",
                  let tsStr = json["timestamp"] as? String,
                  let date = parseDate(tsStr),
                  date >= cutoff,
                  let message = json["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any]
            else { continue }

            let tokens = (usage["input_tokens"]                as? Int ?? 0)
                       + (usage["output_tokens"]               as? Int ?? 0)
                       + (usage["cache_creation_input_tokens"] as? Int ?? 0)
                       + (usage["cache_read_input_tokens"]     as? Int ?? 0)

            guard tokens > 0 else { continue }
            let day = cal.startOfDay(for: date)
            result[day, default: 0] += tokens
        }
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
