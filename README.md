# ClaudePet

macOS menu bar app for monitoring Claude Pro/Max usage with a small animated pixel-art pet.

ClaudePet reads the Claude Code OAuth login already stored on your Mac, checks your Claude usage periodically, and shows the current 5-hour session status from the menu bar. Local Claude Code journal files are used for recent activity charts and pet level progress.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

Language: [English](README.md) | [한국어](README.ko.md)

## Features

### Menu Bar

- Animated pet sprite in the macOS menu bar
- Optional 5-hour session usage percentage
- Display modes: icon only, usage only, or both
- Tooltip with current session status, cached-data state, or auth error

### Usage Tab

- Claude quota rows for:
  - Session (5h)
  - Weekly (7d)
  - Sonnet weekly
  - Opus weekly
- Reset countdowns when the API provides `resets_at`
- Plan badge when `/api/account` returns a plan name
- Extra Usage row when the account has `extra_usage.is_enabled`
- Clear banners for missing auth, expired auth, API errors, and rate limiting
- Last-known-good usage cache when the API is temporarily unavailable

### Stats Tab

- 7-day token trend chart with hover details
- 35-day local activity heatmap
- Total tokens, active days, current streak, active-day average, and week-over-week comparison
- Data is read locally from Claude Code JSONL journals

### Pet Tab

- Larger animated pet display
- Session mood badge based on 5-hour usage:
  - `0-1%`: 휴식중
  - `1-20%`: 안정적
  - `20-40%`: 시동중
  - `40-60%`: 집중중
  - `60-100%`: 과열직전
- Animation speed scales with session usage from 4 fps to 15 fps
- Pet level and XP progress based on this month's local Claude Code token usage
- Today, yesterday, and current-month token counts
- Character picker for Seal and Cat

### Settings

- Authentication status and token source
- Auto-refresh interval: Off, 1m, 2m, 5m, or 10m
- Local notification threshold from 50% to 95%
- Menu bar display mode selector

## Requirements

- macOS 13 Ventura or later
- Claude Code installed and logged in with a Claude Pro or Max account
- Xcode 15 or later when building from source

ClaudePet is for Claude Code OAuth users. It does not use Anthropic API keys.

## Installation

### Download Release

Download the latest DMG from the [Releases](https://github.com/Jjiggu/ClaudePet/releases) page, open it, and drag `ClaudePet.app` to Applications.

### Homebrew

```bash
brew tap Jjiggu/tap
brew install --cask Jjiggu/tap/claudepet
```

### Build From Source

```bash
git clone https://github.com/Jjiggu/ClaudePet.git
cd ClaudePet
open ClaudePet.xcodeproj
```

Select the `ClaudePet` scheme in Xcode and run it with `Cmd+R`.

For a local release DMG:

```bash
./scripts/build-release.sh
```

The script creates `dist/ClaudePet-{version}.dmg` from the Xcode project version.

## Authentication

ClaudePet reads the OAuth token created by Claude Code. No separate API key or setup screen is required.

Install and log in to Claude Code first:

```bash
npm install -g @anthropic-ai/claude-code
claude login
```

Token lookup order:

1. `~/.claude/.credentials.json`
2. macOS Keychain service `Claude Code-credentials`

If no token is found, ClaudePet shows an authentication error and the Settings view reports `Not connected`.

## Data Sources

| Data | Source |
| --- | --- |
| 5-hour, 7-day, Sonnet weekly, Opus weekly quotas | `GET https://api.anthropic.com/api/oauth/usage` |
| Extra Usage | `GET https://api.anthropic.com/api/oauth/usage` |
| Plan name | `GET https://api.anthropic.com/api/account` |
| Daily activity, monthly tokens, pet level | `~/.claude/projects/**/*.jsonl` |

Usage and account API requests are sent to Anthropic with your local Claude Code OAuth token and the `anthropic-beta: oauth-2025-04-20` header.

Journal parsing is local. ClaudePet counts assistant records and sums:

- `input_tokens`
- `output_tokens`
- `cache_creation_input_tokens`
- `cache_read_input_tokens`

## Polling And Caching

- Default auto-refresh interval is 5 minutes.
- Manual refresh uses the same rate-limit guard as automatic refresh.
- ClaudePet never sends usage API requests more frequently than once per minute.
- On HTTP 429 or rate-limit responses, retry backoff doubles from 60 seconds up to 30 minutes.
- The last successful usage response is saved at `~/Library/Application Support/ClaudePet/usage-cache.json`.
- Cached usage is shown with an orange status indicator when fresh data cannot be fetched.
- Plan name is cached for 24 hours.

## Pet Levels

Pet level is based on current-month token usage parsed from local Claude Code journals. The counter resets naturally at the start of each calendar month.

| Level | Monthly tokens |
| --- | ---: |
| Lv.1 | 0 - 49,999,999 |
| Lv.2 | 50,000,000 - 199,999,999 |
| Lv.3 | 200,000,000 - 499,999,999 |
| Lv.4 | 500,000,000 - 999,999,999 |
| Lv.5 | 1,000,000,000+ |

## Characters

| Character | Display name | Menu bar frames | Pet tab frames |
| --- | --- | ---: | ---: |
| Seal | 물범 말랑이 | 6 | 6 |
| Cat | 고양 말랑이 | 2 | 2 |

Selected character, menu bar display mode, refresh interval, notification settings, backoff state, cached plan name, and the latest usage cache are persisted locally.

## Privacy And Security

- ClaudePet reads the same OAuth login that Claude Code stores locally.
- It does not ask for or store Anthropic API keys.
- It stores only app preferences and the last successful usage snapshot locally.
- Local journal parsing stays on your machine.
- Network traffic is limited to the Anthropic usage and account endpoints listed above.
- The app is not sandboxed because it needs access to `~/.claude` files and the Claude Code Keychain item.

## Troubleshooting

### No OAuth Token

Run:

```bash
claude login
```

Then open ClaudePet Settings and check whether Authentication shows `Connected`.

### Rate Limited

Wait for the retry time shown in the popover. Repeated manual refreshes do not bypass the cooldown and can make the upstream rate limit last longer.

### Stats Are Empty

Stats require local Claude Code journal files under `~/.claude/projects`. They appear after Claude Code has written assistant usage records.

### Cached Usage Looks Stale

ClaudePet keeps showing the last successful usage snapshot when the API is unavailable. The popover status indicator turns orange in cached mode.

## Development Notes

- App entry point: `ClaudePet/ClaudePetApp.swift`
- Shared state and polling: `ClaudePet/PetManager.swift`
- OAuth usage/account API client: `ClaudePet/UsageAPIClient.swift`
- Claude Code token loading: `ClaudePet/AuthLoader.swift`
- JSONL journal parsing: `ClaudePet/JournalLoader.swift`
- Menu bar UI: `ClaudePet/MenuBarView.swift`
- Popover tabs and character picker: `ClaudePet/PopoverView.swift`
- Analytics UI: `ClaudePet/AnalyticsView.swift`
- Settings UI: `ClaudePet/SettingsView.swift`

The project has no external package dependencies and currently has no XCTest target.

## License

MIT. See [LICENSE](LICENSE).
