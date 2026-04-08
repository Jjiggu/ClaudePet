# ClaudePet 🦭

A macOS menu bar app that monitors your Claude Pro/Max usage in real time — with an animated pixel-art pet that reacts to how hard you're working.

> Claude Pro/Max 사용량을 실시간으로 모니터링하는 macOS 메뉴바 앱입니다. 세션 사용량에 따라 움직임이 달라지는 픽셀아트 펫 캐릭터와 함께합니다.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## What is ClaudePet? / 소개

ClaudePet sits in your menu bar and shows your Claude session quota at a glance. The pet character (Seal or Cat) animates faster as your 5-hour session fills up — 4 fps at idle, 15 fps when you're running hot. It grows in level as your monthly token usage accumulates, like a Tamagotchi for your Claude usage.

> 메뉴바에 상주하며 Claude 5시간 세션 쿼터를 한눈에 확인할 수 있습니다. 펫(물범 또는 고양이)은 세션 사용량에 따라 애니메이션 속도가 달라지고, 월간 토큰 사용량이 쌓이면 레벨이 오릅니다.

---

## Features / 기능

### Usage Tab / 사용량 탭
- **4 live quota bars** — 5h session, 7-day weekly, Sonnet weekly, Opus weekly
- **Extra Usage card** — shows monthly overage when enabled on your plan
- **Plan name badge** — displays your current Claude plan
- **Reset countdown** — shows exactly when each quota resets
- **Error banners** — clear hints when authentication fails or you're rate limited
- **Cached display** — shows last known usage with an orange indicator when the API is unavailable

> 5시간 세션 / 7일 주간 / 소네트 주간 / 오퍼스 주간 쿼터를 프로그레스 바로 표시합니다. API 오류 시 마지막 캐시 데이터를 주황색 표시와 함께 보여줍니다.

### Stats Tab / 통계 탭
- **35-day activity heatmap** — GitHub-style grid showing daily token usage
- **7-day trend chart** — cubic Bézier curve with hover tooltips
- **Summary cards** — current streak, daily average, week-over-week comparison
- **Monthly totals** — total tokens and active day count

> 35일 토큰 히트맵, 7일 트렌드 차트, 연속 사용일·일평균·주간 비교 카드를 제공합니다.

### Pet Tab / 펫 탭
- **Animated pet display** — reacts to your current session activity
- **Session condition badge** — 5 moods based on your 5h quota usage
- **XP level bar** — progress toward next level (Lv.1–5)
- **Today / Yesterday token counts** — from local Claude Code journals
- **Character selector** — switch between Seal and Cat

> 세션 상태에 따른 펫 애니메이션, 기분 배지, 레벨 진행 바, 오늘/어제 토큰 수를 보여줍니다.

### Menu Bar / 메뉴바
- Animated pet sprite + optional usage percentage
- Display modes: icon only / percentage only / both

> 메뉴바에 애니메이션 펫과 사용량 퍼센트를 함께 또는 개별로 표시할 수 있습니다.

### Settings / 설정
- Auto-refresh interval: Off / 1m / 2m / 5m / 10m
- Local notifications when session crosses a threshold (50–95%)
- Menu bar display mode selector

---

## Requirements / 요구사항

- macOS 13 (Ventura) or later
- [Claude Code](https://claude.ai/code) installed and authenticated (`claude login`)
- Claude Pro or Max subscription

> Xcode는 소스 빌드 시에만 필요합니다. 릴리스 빌드를 다운로드하면 별도 설치 불필요합니다.

---

## Installation / 설치

### Option 1: Download Release (recommended) / 릴리스 다운로드 (권장)

Download the latest `.dmg` from the [Releases](../../releases) page, open it, and drag ClaudePet to your Applications folder.

> [Releases](../../releases) 페이지에서 최신 `.dmg`를 다운로드하여 응용 프로그램 폴더로 드래그하세요.

### Option 2: Build from Source / 소스 빌드

```bash
git clone https://github.com/Jjiggu/ClaudePet.git
cd ClaudePet
open ClaudePet.xcodeproj
```

Press ⌘R in Xcode to build and run.

---

## Authentication / 인증

ClaudePet reads the OAuth token that Claude Code stores locally — no separate API key needed.

> Claude Code가 로컬에 저장한 OAuth 토큰을 자동으로 읽습니다. 별도 API 키 불필요합니다.

**Step 1**: Install Claude Code
```bash
npm install -g @anthropic-ai/claude-code
```

**Step 2**: Log in
```bash
claude login
```

ClaudePet automatically detects your token from:
1. `~/.claude/.credentials.json` (primary)
2. macOS Keychain — service `Claude Code-credentials` (fallback)

If the token is missing or expired, the app shows an error banner with instructions.

> 토큰이 없거나 만료된 경우 앱 내 에러 배너에서 안내를 확인할 수 있습니다.

---

## Pet System / 펫 시스템

### Session Conditions / 세션 상태 (5h quota)

| Condition | Usage | Description |
|-----------|-------|-------------|
| Idle / 휴식중 | 0–1% | Resting quietly |
| Calm / 안정적 | 1–20% | Plenty of headroom |
| Warming Up / 시동중 | 20–40% | Getting into it |
| Focused / 집중중 | 40–60% | In the zone |
| Overloaded / 과열직전 | 60–100% | Running hot |

Animation speed scales with session usage: **4 fps** (idle) → **15 fps** (max).

### Pet Levels / 펫 레벨 (monthly tokens from local journals)

| Level | Monthly Tokens |
|-------|----------------|
| Lv.1 | 0 – 500K |
| Lv.2 | 500K – 2M |
| Lv.3 | 2M – 5M |
| Lv.4 | 5M – 10M |
| Lv.5 | 10M+ |

Token counts are parsed from `~/.claude/projects/**/*.jsonl` (Claude Code session logs) — no API calls needed for this.

> 월간 토큰 수는 로컬 Claude Code 세션 로그(JSONL)에서 파싱합니다. API 호출 없이 계산됩니다.

---

## Characters / 캐릭터

| Character | 이름 | Frames |
|-----------|------|--------|
| Seal | 물범 말랑이 | 6 frames |
| Cat | 고양 말랑이 | 2 frames |

Switch characters anytime from the Pet tab. Selection persists across restarts.

> 펫 탭에서 언제든지 캐릭터를 변경할 수 있으며, 재시작 후에도 유지됩니다.

---

## How It Works / 동작 원리

**Data sources / 데이터 소스:**

| Source | Used for |
|--------|----------|
| `GET /api/oauth/usage` (Anthropic API) | Session %, weekly quotas, Extra Usage |
| `~/.claude/projects/**/*.jsonl` | Monthly tokens, daily activity, pet level |
| `GET /api/account` (Anthropic API) | Plan name (cached 24h) |

**Polling behavior / 폴링 동작:**
- Default refresh: every 5 minutes (configurable)
- Minimum gap between requests: 60 seconds
- On HTTP 429: backoff doubles (60s → 120s → … → 1800s max), resets on success
- Last successful data is cached locally and shown with an orange indicator when stale

**Memory footprint:** ~20–30 MB

---

## Tech Stack / 기술 스택

- Swift 5.9+, SwiftUI, AppKit
- macOS 13+ (Ventura+)
- Zero external dependencies / 외부 의존성 없음
- Swift Concurrency (async/await)
- `LSUIElement = true` — menu bar only, no Dock icon

---

## Privacy / 개인정보 처리

- No data leaves your device except the two Anthropic API calls above (using your own OAuth token)
- Token is read from local file / Keychain — never stored elsewhere by this app
- JSONL parsing happens entirely locally

> 위 2개의 Anthropic API 호출 외에는 어떠한 데이터도 외부로 전송되지 않습니다. JSONL 파싱은 로컬에서만 이루어집니다.

---

## Acknowledgements / 참고

- [Claude God](https://github.com/Lcharvol/Claude-God) (MIT) — OAuth API integration patterns
- [TokenEater](https://github.com/AThevon/TokenEater) (MIT) — lightweight architecture reference
- [RunCat](https://kyome.io/runcat/) — menu bar animation concept

---

## License

MIT — see [LICENSE](LICENSE)
