#!/usr/bin/env swift
// test_journal_loader.swift — JournalLoader 로직 검증
// 실행:
// DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift -Xcc -fmodules-cache-path=/tmp/claudepet-module-cache ClaudePet/JournalLoader.swift test_journal_loader.swift

import Foundation

var passed = 0
var failed = 0

func test(_ name: String, _ block: () throws -> Bool) {
    do {
        if try block() {
            print("  ✅ \(name)")
            passed += 1
        } else {
            print("  ❌ \(name) — assertion failed")
            failed += 1
        }
    } catch {
        print("  ❌ \(name) — threw: \(error)")
        failed += 1
    }
}

func makeUsageLine(
    type: String = "assistant",
    timestamp: String,
    input: Int = 0,
    output: Int = 0,
    cacheCreate: Int = 0,
    cacheRead: Int = 0
) -> String {
    """
    {"type":"\(type)","timestamp":"\(timestamp)","message":{"usage":{"input_tokens":\(input),"output_tokens":\(output),"cache_creation_input_tokens":\(cacheCreate),"cache_read_input_tokens":\(cacheRead)}}}
    """
}

print("\n=== 1. JournalLoader helpers ===")

test("tokenCount sums all token fields") {
    let usage: [String: Any] = [
        "input_tokens": 10,
        "output_tokens": 20,
        "cache_creation_input_tokens": 5,
        "cache_read_input_tokens": 3
    ]
    return JournalLoader.tokenCount(from: usage) == 38
}

test("record parses assistant usage line") {
    let line = makeUsageLine(timestamp: "2026-04-06T00:00:00Z", input: 12, output: 8, cacheRead: 2)
    guard let record = JournalLoader.record(from: line) else { return false }
    let expectedDate = ISO8601DateFormatter().date(from: "2026-04-06T00:00:00Z")
    return record.tokens == 22 && record.date == expectedDate
}

test("record ignores non-assistant and zero-token lines") {
    let userLine = makeUsageLine(type: "user", timestamp: "2026-04-06T00:00:00Z", input: 1)
    let zeroLine = makeUsageLine(timestamp: "2026-04-06T00:00:00Z")
    return JournalLoader.record(from: userLine) == nil
        && JournalLoader.record(from: zeroLine) == nil
}

print("\n=== 2. Journal snapshot ===")

let tempRoot = FileManager.default.temporaryDirectory
    .appendingPathComponent("ClaudePetJournalTests-\(UUID().uuidString)", isDirectory: true)
try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: tempRoot) }

let nestedDir = tempRoot.appendingPathComponent("nested", isDirectory: true)
try FileManager.default.createDirectory(at: nestedDir, withIntermediateDirectories: true)

let fileOne = tempRoot.appendingPathComponent("session-one.jsonl")
let fileTwo = nestedDir.appendingPathComponent("session-two.jsonl")

let fileOneLines = [
    makeUsageLine(timestamp: "2026-04-06T09:00:00Z", input: 10, output: 5),
    makeUsageLine(timestamp: "2026-04-01T09:00:00Z", input: 20),
    makeUsageLine(timestamp: "2026-03-05T09:00:00Z", output: 7),
    makeUsageLine(type: "user", timestamp: "2026-04-06T10:00:00Z", input: 999)
].joined(separator: "\n")

let fileTwoLines = [
    makeUsageLine(timestamp: "2026-02-28T09:00:00Z", input: 100),
    makeUsageLine(timestamp: "2026-04-06T11:00:00Z", cacheCreate: 4, cacheRead: 1)
].joined(separator: "\n")

try fileOneLines.write(to: fileOne, atomically: true, encoding: .utf8)
try fileTwoLines.write(to: fileTwo, atomically: true, encoding: .utf8)

test("loadSnapshot returns daily usage and monthly total from one scan") {
    let now = ISO8601DateFormatter().date(from: "2026-04-06T12:00:00Z")!
    let snapshot = JournalLoader.loadSnapshot(days: 35, now: now, baseURL: tempRoot)
    let cal = Calendar.current

    let april6 = cal.startOfDay(for: ISO8601DateFormatter().date(from: "2026-04-06T09:00:00Z")!)
    let april1 = cal.startOfDay(for: ISO8601DateFormatter().date(from: "2026-04-01T09:00:00Z")!)
    let march5 = cal.startOfDay(for: ISO8601DateFormatter().date(from: "2026-03-05T09:00:00Z")!)

    return snapshot.dailyUsage[april6] == 20
        && snapshot.dailyUsage[april1] == 20
        && snapshot.dailyUsage[march5] == 7
        && snapshot.monthlyTokens == 40
}

test("load and currentMonthTotal wrappers stay aligned with snapshot") {
    let now = ISO8601DateFormatter().date(from: "2026-04-06T12:00:00Z")!
    let dailyUsage = JournalLoader.load(days: 35, now: now, baseURL: tempRoot)
    let monthlyTotal = JournalLoader.currentMonthTotal(now: now, baseURL: tempRoot)
    let april6 = Calendar.current.startOfDay(for: ISO8601DateFormatter().date(from: "2026-04-06T09:00:00Z")!)

    return dailyUsage[april6] == 20 && monthlyTotal == 40
}

print("\n─────────────────────")
print("결과: \(passed) passed, \(failed) failed")
if failed == 0 {
    print("🎉 All tests passed")
} else {
    print("⚠️  \(failed) test(s) failed")
}
print("")
