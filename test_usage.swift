#!/usr/bin/env swift
// test_usage.swift — ClaudePet 사용량 로직 검증
// 실행: swift test_usage.swift

import Foundation

// ─────────────────────────────────────────────
// MARK: - Models (PetManager와 동일한 구조 복사)
// ─────────────────────────────────────────────

struct UsageQuota: Decodable {
    let utilization: Double
    let resetsAt: Date?
    var percent: Double { min(utilization / 100.0, 1.0) }
    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

struct OAuthUsageResponse: Decodable {
    let fiveHour: UsageQuota?
    let sevenDay: UsageQuota?
    let sevenDaySonnet: UsageQuota?
    let sevenDayOpus: UsageQuota?
    enum CodingKeys: String, CodingKey {
        case fiveHour       = "five_hour"
        case sevenDay       = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus   = "seven_day_opus"
    }
}

// ─────────────────────────────────────────────
// MARK: - Decoder (PetManager와 동일한 로직)
// ─────────────────────────────────────────────

let isoFrac: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return f
}()
let isoPlain: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()

func decode(_ data: Data) throws -> OAuthUsageResponse {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { dec in
        let str = try dec.singleValueContainer().decode(String.self)
        if let d = isoFrac.date(from: str)  { return d }
        if let d = isoPlain.date(from: str) { return d }
        throw DecodingError.dataCorruptedError(
            in: try dec.singleValueContainer(),
            debugDescription: "Cannot parse date: \(str)"
        )
    }
    return try decoder.decode(OAuthUsageResponse.self, from: data)
}

// ─────────────────────────────────────────────
// MARK: - Test Runner
// ─────────────────────────────────────────────

var passed = 0
var failed = 0

func test(_ name: String, _ block: () throws -> Bool) {
    do {
        let result = try block()
        if result {
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

// ─────────────────────────────────────────────
// MARK: - Tests
// ─────────────────────────────────────────────

print("\n=== 1. JSON 디코딩 ===")

test("정상 응답 파싱") {
    let json = """
    {
        "five_hour":       {"utilization": 87.0, "resets_at": "2026-04-02T16:59:59Z"},
        "seven_day":       {"utilization": 7.0,  "resets_at": "2026-04-09T05:00:00Z"},
        "seven_day_sonnet": null,
        "seven_day_opus":   null
    }
    """
    let r = try decode(Data(json.utf8))
    return r.fiveHour?.utilization == 87.0
        && r.sevenDay?.utilization == 7.0
        && r.sevenDaySonnet == nil
        && r.sevenDayOpus == nil
}

test("utilization 0%") {
    let json = """
    {"five_hour":{"utilization":0.0,"resets_at":"2026-04-02T16:59:59Z"},
     "seven_day":null,"seven_day_sonnet":null,"seven_day_opus":null}
    """
    let r = try decode(Data(json.utf8))
    return r.fiveHour?.utilization == 0.0
}

test("utilization 100%") {
    let json = """
    {"five_hour":{"utilization":100.0,"resets_at":"2026-04-02T16:59:59Z"},
     "seven_day":null,"seven_day_sonnet":null,"seven_day_opus":null}
    """
    let r = try decode(Data(json.utf8))
    return r.fiveHour?.percent == 1.0   // capped at 1.0
}

test("fractional seconds 날짜 파싱") {
    let json = """
    {"five_hour":{"utilization":50.0,"resets_at":"2026-04-02T16:59:59.123Z"},
     "seven_day":null,"seven_day_sonnet":null,"seven_day_opus":null}
    """
    let r = try decode(Data(json.utf8))
    return r.fiveHour != nil
}

test("resets_at null 허용") {
    let json = """
    {"five_hour":{"utilization":12.0,"resets_at":null},
     "seven_day":null,"seven_day_sonnet":null,"seven_day_opus":null}
    """
    let r = try decode(Data(json.utf8))
    return r.fiveHour?.utilization == 12.0 && r.fiveHour?.resetsAt == nil
}

test("모든 필드 null") {
    let json = """
    {"five_hour":null,"seven_day":null,"seven_day_sonnet":null,"seven_day_opus":null}
    """
    let r = try decode(Data(json.utf8))
    return r.fiveHour == nil && r.sevenDay == nil
}

test("에러 바디(HTTP 200)는 error 키로 감지됨 — 데이터 덮어쓰기 방지") {
    // 모든 필드가 optional이라 decode 자체는 성공하지만,
    // app은 먼저 "error" 키를 확인해야 함 (PetManager 수정 사항)
    let json = """
    {"error":{"type":"rate_limit_error","message":"Rate limited."}}
    """
    guard let raw = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any] else { return false }
    let hasErrorKey = raw["error"] != nil
    let decoded = try decode(Data(json.utf8))
    // decode는 성공하지만 모두 nil → app이 error 키를 먼저 체크하는 게 올바름
    return hasErrorKey && decoded.fiveHour == nil && decoded.sevenDay == nil
}

print("\n=== 2. percent 계산 ===")

test("50% utilization → percent 0.5") {
    let json = """
    {"five_hour":{"utilization":50.0,"resets_at":"2026-04-02T16:59:59Z"},
     "seven_day":null,"seven_day_sonnet":null,"seven_day_opus":null}
    """
    let r = try decode(Data(json.utf8))
    return r.fiveHour?.percent == 0.5
}

test("110% utilization → percent 1.0 (상한 clamp)") {
    let json = """
    {"five_hour":{"utilization":110.0,"resets_at":"2026-04-02T16:59:59Z"},
     "seven_day":null,"seven_day_sonnet":null,"seven_day_opus":null}
    """
    let r = try decode(Data(json.utf8))
    return r.fiveHour?.percent == 1.0
}

print("\n=== 3. 실제 Keychain 토큰 로드 ===")

test("Keychain에서 accessToken 읽기") {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    task.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    try task.run()
    task.waitUntilExit()
    let raw = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
          let oauth = json["claudeAiOauth"] as? [String: Any],
          let token = oauth["accessToken"] as? String,
          token.hasPrefix("sk-ant-") else { return false }
    return true
}

test("토큰 만료 여부 확인") {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
    task.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()
    try task.run()
    task.waitUntilExit()
    let raw = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
          let oauth = json["claudeAiOauth"] as? [String: Any],
          let expiresMs = oauth["expiresAt"] as? Double else { return false }
    let expiresDate = Date(timeIntervalSince1970: expiresMs / 1000)
    let isValid = expiresDate > Date()
    print("     만료: \(expiresDate)  |  현재: \(Date())  |  유효: \(isValid)")
    return isValid
}

// ─────────────────────────────────────────────
print("\n─────────────────────")
print("결과: \(passed) passed, \(failed) failed")
if failed == 0 { print("🎉 All tests passed") } else { print("⚠️  \(failed) test(s) failed") }
print("")
