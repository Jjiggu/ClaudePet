# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Open `ClaudePet.xcodeproj` in Xcode and press ⌘R. There is no CLI build system — all building, running, and testing is done through Xcode.

The app runs as a macOS menu bar extra (`LSUIElement = true`; no Dock icon). When run from Xcode, the popover appears by clicking the status bar icon.

There are no unit test targets. `test_journal_loader.swift` and `test_usage.swift` at the repo root are standalone Swift scripts used for manual verification only.

## Architecture

**Single shared state object**: `PetManager` (`@MainActor final class ObservableObject`) owns all state and is passed as `@ObservedObject` to every view. There is no separate ViewModel layer.

**Data flow**:
1. `AuthLoader` reads the OAuth token from `~/.claude/.credentials.json` (primary) or macOS Keychain service `"Claude Code-credentials"` (fallback).
2. `PetManager.fetchUsage()` calls `GET https://api.anthropic.com/api/oauth/usage` with `anthropic-beta: oauth-2025-04-20`. Returns `UsageQuota` for `five_hour`, `seven_day`, `seven_day_sonnet`, `seven_day_opus`, and optionally `ExtraUsage`.
3. `JournalLoader` scans `~/.claude/projects/**/*.jsonl` off the main thread (`Task.detached(priority: .utility)`) and returns `JournalSnapshot` — daily token buckets and monthly total. Records are `type: "assistant"` entries; tokens = sum of `input_tokens + output_tokens + cache_creation_input_tokens + cache_read_input_tokens`.
4. `PetManager.fetchPlanInfo()` attempts `GET https://api.anthropic.com/api/account` to resolve a plan name string — field name TBD (logs JSON to console as `[ClaudePet] /api/account:`).

**Polling**: `Task.sleep` loop (not `Timer`). `refreshInterval` (UserDefaults, default 300s) controls the cadence. On 429, `rateLimitBackoff` doubles (60s → 1800s max) and resets on success. A `minFetchInterval` of 60s prevents back-to-back calls. **Never add direct API calls for debugging** — the API has strict rate limits that compound across calls.

**Pet logic**:
- `PetStage` (1–5) is derived from `fiveHour.percent` (5h session quota).
- `petLevel` (1–5) is derived from `monthlyTokens` (JSONL). Thresholds: 0 / 500K / 2M / 5M / 10M.
- `animationFPS` scales with session usage (4 fps idle → 15 fps at max). RunCat-style.
- `SessionMood` drives dialogue/badge text in the Pet tab (Korean strings).

**`@Published` didSet guard**: `isInitialized` flag in `PetManager.init()` prevents `startPolling()` from being called during `@Published` property assignment (Swift fires `didSet` even during `init`).

## UI Structure

```
ClaudePetApp
├── MenuBarView          — status bar label (AnimatedPetView + optional usage %)
└── PopoverView (280pt wide)
    ├── Tab bar          — Usage / Stats / Pet + gear icon
    ├── ScrollView (360pt tall, fixed)
    │   ├── MainView         — 4 usage rows + optional ExtraUsage row
    │   ├── AnalyticsView    — 35-day token heatmap (7×5 grid, GitHub-style)
    │   └── PetTabView       — animated pet, mood badge, session card, stats
    ├── Bottom bar (fixed)   — Reset button + status dot + power button
    └── Routes: CharacterPickerView, SettingsView (replace tab content)
```

`PopoverView` uses a `Route` enum (`tabs` / `characterPicker` / `settings`) to swap full-screen sub-views rather than pushing onto a navigation stack.

## Asset Naming Convention

Sprite frames follow `{prefix}_{frameIndex}` naming in Assets.xcassets:

| Prefix | Pet | Location |
|---|---|---|
| `pet_stage1` | Seal | Menu bar (6 frames: `_0`–`_5`) |
| `pet_stage1_large` | Seal | Pet tab (6 frames: `_0`–`_5`) |
| `pet_cat_menu` | Cat | Menu bar (2 frames: `_0`–`_1`) |
| `pet_cat_large` | Cat | Pet tab (2 frames: `_0`–`_1`) |

`AnimatedPetView` discovers frames dynamically via `NSImage(named:)` — no hardcoded frame counts. It checks `{prefix}` first (single image), then `{prefix}_0`, `{prefix}_1`, … until nil.

**Scale slot rule**: All imagesets must use the **1x slot only**. If a PNG is placed in the 2x slot on a Retina display it renders at half the intended size, causing visible size jumps between frames.

## Key UserDefaults Keys

| Key | Type | Default |
|---|---|---|
| `selectedPetType` | String | `"seal"` |
| `menuBarDisplayMode` | String | `"both"` |
| `refreshInterval` | Int | `300` |
| `notificationsEnabled` | Bool | `false` |
| `notificationThreshold` | Double | `0.8` |

## Known Constraints

- `UsageQuota.utilization` is 0–100 (not 0–1). `percent` property normalises to 0–1 for progress bars.
- `ExtraUsage` only renders when `isEnabled == true`.
- `planName` may be nil if `/api/account` is unavailable or returns an unrecognised field name — check console logs `[ClaudePet] /api/account:` to confirm the actual JSON key.
- `MenuBarExtra(.window)` style requires `NSApp.activate(ignoringOtherApps: true)` on appear to avoid the first click being swallowed by window activation.
