#!/usr/bin/env swift
// test_view_state.swift — SpriteFrameCatalog / UsageViewState regression checks
// 실행:
// DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift \
//   -Xcc -fmodules-cache-path=/tmp/claudepet-module-cache \
//   ClaudePet/SpriteFrameCatalog.swift ClaudePet/UsageViewState.swift test_view_state.swift

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

print("\n=== 1. SpriteFrameCatalog ===")

test("prefers numbered frames when both numbered and single-frame assets exist") {
    let available: Set<String> = ["pet_cat_menu", "pet_cat_menu_0", "pet_cat_menu_1"]
    let frames = SpriteFrameCatalog.frames(for: "pet_cat_menu") { available.contains($0) }
    return frames == ["pet_cat_menu_0", "pet_cat_menu_1"]
}

test("falls back to single-frame asset when no numbered frames exist") {
    let available: Set<String> = ["pet_preview_cat"]
    let frames = SpriteFrameCatalog.frames(for: "pet_preview_cat") { available.contains($0) }
    return frames == ["pet_preview_cat"]
}

test("returns first available prefix in search order") {
    let available: Set<String> = ["pet_stage2_0", "pet_stage2_1"]
    let frames = SpriteFrameCatalog.firstAvailableFrames(
        prefixes: ["pet_stage3", "pet_stage2", "pet_stage1"]
    ) { available.contains($0) }
    return frames == ["pet_stage2_0", "pet_stage2_1"]
}

print("\n=== 2. UsageViewState ===")

test("keeps usage content visible when stale data exists alongside an error") {
    let state = UsageViewState.resolve(hasUsageData: true, isLoading: false, errorMessage: "Rate limited")
    return state.showsUsageContent
        && state.banner == UsageBannerState(style: .error, message: "Rate limited")
}

test("shows loading banner before first successful fetch") {
    let state = UsageViewState.resolve(hasUsageData: false, isLoading: true, errorMessage: nil)
    return !state.showsUsageContent
        && state.banner == UsageBannerState(style: .info, message: "Loading")
}

test("hides banner when data is available and no status message exists") {
    let state = UsageViewState.resolve(hasUsageData: true, isLoading: false, errorMessage: nil)
    return state.showsUsageContent && state.banner == nil
}

print("\n─────────────────────")
print("결과: \(passed) passed, \(failed) failed")
if failed == 0 {
    print("🎉 All tests passed")
} else {
    print("⚠️  \(failed) test(s) failed")
}
print("")
