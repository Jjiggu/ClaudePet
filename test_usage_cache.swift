#!/usr/bin/env swift
// test_usage_cache.swift - UsageSnapshotCache regression checks
// Run:
// { cat ClaudePet/UsageAPIClient.swift; printf '\n'; cat ClaudePet/UsageSnapshotCache.swift; printf '\n'; sed '1d' test_usage_cache.swift; } > /tmp/combined-usage-cache-tests.swift
// DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer /usr/bin/xcrun swift \
//   -Xcc -fmodules-cache-path=/tmp/claudepet-module-cache \
//   /tmp/combined-usage-cache-tests.swift

import Foundation

var passed = 0
var failed = 0

func test(_ name: String, _ block: () throws -> Bool) {
    do {
        if try block() {
            print("  PASS \(name)")
            passed += 1
        } else {
            print("  FAIL \(name) - assertion failed")
            failed += 1
        }
    } catch {
        print("  FAIL \(name) - threw: \(error)")
        failed += 1
    }
}

func makeCacheFile() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ClaudePetUsageCacheTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root.appendingPathComponent("usage-cache.json")
}

func makeUsage() -> OAuthUsageResponse {
    OAuthUsageResponse(
        fiveHour: UsageQuota(
            utilization: 42,
            resetsAt: Date(timeIntervalSince1970: 1_775_520_000)
        ),
        sevenDay: UsageQuota(
            utilization: 12.5,
            resetsAt: nil
        ),
        sevenDaySonnet: UsageQuota(
            utilization: 7,
            resetsAt: Date(timeIntervalSince1970: 1_775_606_400)
        ),
        sevenDayOpus: nil,
        extraUsage: ExtraUsage(
            isEnabled: true,
            monthlyLimit: 2_000,
            usedCredits: 123.45,
            utilization: 6.17
        )
    )
}

func makeSnapshot(schemaVersion: Int = CachedUsageSnapshot.currentSchemaVersion) -> CachedUsageSnapshot {
    CachedUsageSnapshot(
        fetchedAt: Date(timeIntervalSince1970: 1_775_433_600),
        usage: makeUsage(),
        planName: "Max",
        schemaVersion: schemaVersion
    )
}

print("\n=== UsageSnapshotCache ===")

test("missing cache returns nil") {
    let fileURL = try makeCacheFile()
    let cache = UsageSnapshotCache(fileURL: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

    return cache.load() == nil
}

test("save and load round-trips last successful usage") {
    let fileURL = try makeCacheFile()
    let cache = UsageSnapshotCache(fileURL: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

    let snapshot = makeSnapshot()
    try cache.save(snapshot)

    guard let loaded = cache.load() else { return false }
    return loaded.schemaVersion == CachedUsageSnapshot.currentSchemaVersion
        && loaded.fetchedAt == snapshot.fetchedAt
        && loaded.planName == "Max"
        && loaded.usage.fiveHour?.utilization == 42
        && loaded.usage.fiveHour?.resetsAt == snapshot.usage.fiveHour?.resetsAt
        && loaded.usage.sevenDay?.utilization == 12.5
        && loaded.usage.sevenDay?.resetsAt == nil
        && loaded.usage.sevenDaySonnet?.utilization == 7
        && loaded.usage.sevenDayOpus == nil
        && loaded.usage.extraUsage?.isEnabled == true
        && loaded.usage.extraUsage?.monthlyLimit == 2_000
        && loaded.usage.extraUsage?.usedCredits == 123.45
        && loaded.usage.extraUsage?.utilization == 6.17
}

test("outdated schema is ignored") {
    let fileURL = try makeCacheFile()
    let cache = UsageSnapshotCache(fileURL: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

    try cache.save(makeSnapshot(schemaVersion: CachedUsageSnapshot.currentSchemaVersion + 1))

    return cache.load() == nil
}

test("corrupt cache is ignored") {
    let fileURL = try makeCacheFile()
    let cache = UsageSnapshotCache(fileURL: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

    try FileManager.default.createDirectory(
        at: fileURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try "not-json".write(to: fileURL, atomically: true, encoding: .utf8)

    return cache.load() == nil
}

test("remove deletes cached snapshot") {
    let fileURL = try makeCacheFile()
    let cache = UsageSnapshotCache(fileURL: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

    try cache.save(makeSnapshot())
    cache.remove()

    return cache.load() == nil && !FileManager.default.fileExists(atPath: fileURL.path)
}

test("serialized cache does not contain credential markers") {
    let fileURL = try makeCacheFile()
    let cache = UsageSnapshotCache(fileURL: fileURL)
    defer { try? FileManager.default.removeItem(at: fileURL.deletingLastPathComponent()) }

    try cache.save(makeSnapshot())
    let contents = try String(contentsOf: fileURL, encoding: .utf8)
    let forbiddenMarkers = [
        "access_token",
        "refresh_token",
        "authorization",
        "bearer",
        "oauth_token",
        "credentials"
    ]

    return forbiddenMarkers.allSatisfy {
        contents.range(of: $0, options: .caseInsensitive) == nil
    }
}

print("\n---------------------")
print("Result: \(passed) passed, \(failed) failed")
if failed == 0 {
    print("All tests passed")
} else {
    print("\(failed) test(s) failed")
}
print("")
