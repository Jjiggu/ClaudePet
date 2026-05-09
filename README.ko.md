# ClaudePet

Claude Pro/Max 사용량을 macOS 메뉴 막대에서 확인하는 작은 픽셀아트 펫 앱입니다.

ClaudePet은 Mac에 저장된 Claude Code OAuth 로그인을 읽고, Claude 사용량을 주기적으로 확인해서 현재 5시간 세션 상태를 메뉴 막대에 표시합니다. 최근 활동 차트와 펫 레벨 진행도는 로컬 Claude Code 저널 파일을 기반으로 계산합니다.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

언어: [English](README.md) | [한국어](README.ko.md)

## 기능

### 메뉴 막대

- macOS 메뉴 막대에 표시되는 애니메이션 펫 스프라이트
- 선택적으로 표시되는 5시간 세션 사용률
- 표시 모드: 아이콘만, 사용률만, 둘 다
- 현재 세션 상태, 캐시 데이터 상태, 인증 오류를 알려주는 툴팁

### Usage 탭

- Claude 쿼터 행:
  - Session (5h)
  - Weekly (7d)
  - Sonnet weekly
  - Opus weekly
- API가 `resets_at`을 제공할 때 표시되는 리셋 카운트다운
- `/api/account`에서 플랜명이 내려올 때 표시되는 플랜 배지
- 계정에서 `extra_usage.is_enabled`가 켜져 있을 때 표시되는 Extra Usage 행
- 인증 누락, 만료된 인증, API 오류, rate limit을 알려주는 배너
- API를 일시적으로 사용할 수 없을 때 마지막으로 성공한 사용량 캐시 표시

### Stats 탭

- hover 상세 정보를 제공하는 7일 토큰 추이 차트
- 35일 로컬 활동 히트맵
- 총 토큰, 활성 일수, 현재 연속 사용일, 활성일 평균, 전주 대비 비교
- 데이터는 로컬 Claude Code JSONL 저널에서 읽습니다.

### Pet 탭

- 더 크게 표시되는 애니메이션 펫
- 5시간 사용률 기반 세션 기분 배지:
  - `0-1%`: 휴식중
  - `1-20%`: 안정적
  - `20-40%`: 시동중
  - `40-60%`: 집중중
  - `60-100%`: 과열직전
- 세션 사용률에 따라 4 fps에서 15 fps까지 변하는 애니메이션 속도
- 이번 달 로컬 Claude Code 토큰 사용량 기반 펫 레벨과 XP 진행도
- 오늘, 어제, 이번 달 토큰 수
- 물범과 고양이를 고를 수 있는 캐릭터 선택 화면

### Settings

- 인증 상태와 토큰 출처
- 자동 새로고침 간격: Off, 1m, 2m, 5m, 10m
- 50%에서 95%까지 설정 가능한 로컬 알림 기준
- 메뉴 막대 표시 모드 선택

## 요구사항

- macOS 13 Ventura 이상
- Claude Pro 또는 Max 계정으로 로그인된 Claude Code
- 소스에서 빌드할 경우 Xcode 15 이상

ClaudePet은 Claude Code OAuth 사용자를 위한 앱입니다. Anthropic API 키는 사용하지 않습니다.

## 설치

### 릴리스 다운로드

[Releases](https://github.com/Jjiggu/ClaudePet/releases) 페이지에서 최신 DMG를 다운로드하고, 연 뒤 `ClaudePet.app`을 Applications 폴더로 드래그하세요.

### Homebrew

```bash
brew tap Jjiggu/tap
brew install --cask Jjiggu/tap/claudepet
```

### 소스에서 빌드

```bash
git clone https://github.com/Jjiggu/ClaudePet.git
cd ClaudePet
open ClaudePet.xcodeproj
```

Xcode에서 `ClaudePet` 스킴을 선택하고 `Cmd+R`로 실행하세요.

로컬 릴리스 DMG를 만들려면 다음을 실행합니다.

```bash
./scripts/build-release.sh
```

이 스크립트는 Xcode 프로젝트 버전을 기준으로 `dist/ClaudePet-{version}.dmg`를 생성합니다.

## 인증

ClaudePet은 Claude Code가 만든 OAuth 토큰을 읽습니다. 별도 API 키나 설정 화면은 필요하지 않습니다.

먼저 Claude Code를 설치하고 로그인하세요.

```bash
npm install -g @anthropic-ai/claude-code
claude login
```

토큰 조회 순서:

1. `~/.claude/.credentials.json`
2. macOS Keychain 서비스 `Claude Code-credentials`

토큰을 찾지 못하면 ClaudePet이 인증 오류를 표시하고, Settings 화면의 Authentication 상태가 `Not connected`로 표시됩니다.

## 데이터 소스

| 데이터 | 소스 |
| --- | --- |
| 5시간, 7일, Sonnet weekly, Opus weekly 쿼터 | `GET https://api.anthropic.com/api/oauth/usage` |
| Extra Usage | `GET https://api.anthropic.com/api/oauth/usage` |
| 플랜명 | `GET https://api.anthropic.com/api/account` |
| 일별 활동, 월간 토큰, 펫 레벨 | `~/.claude/projects/**/*.jsonl` |

사용량과 계정 API 요청은 로컬 Claude Code OAuth 토큰과 `anthropic-beta: oauth-2025-04-20` 헤더를 사용해 Anthropic으로 전송됩니다.

저널 파싱은 로컬에서만 수행됩니다. ClaudePet은 assistant 레코드를 읽고 다음 값을 합산합니다.

- `input_tokens`
- `output_tokens`
- `cache_creation_input_tokens`
- `cache_read_input_tokens`

## 폴링과 캐시

- 기본 자동 새로고침 간격은 5분입니다.
- 수동 새로고침도 자동 새로고침과 같은 rate limit 보호를 사용합니다.
- ClaudePet은 사용량 API 요청을 1분보다 자주 보내지 않습니다.
- HTTP 429 또는 rate limit 응답을 받으면 재시도 backoff가 60초에서 최대 30분까지 2배씩 증가합니다.
- 마지막으로 성공한 사용량 응답은 `~/Library/Application Support/ClaudePet/usage-cache.json`에 저장됩니다.
- 새 데이터를 가져올 수 없으면 캐시된 사용량을 주황색 상태 표시와 함께 보여줍니다.
- 플랜명은 24시간 동안 캐시됩니다.

## 펫 레벨

펫 레벨은 로컬 Claude Code 저널에서 파싱한 이번 달 토큰 사용량을 기준으로 계산합니다. 카운터는 매월 1일 자연스럽게 초기화됩니다.

| 레벨 | 월간 토큰 |
| --- | ---: |
| Lv.1 | 0 - 49,999,999 |
| Lv.2 | 50,000,000 - 199,999,999 |
| Lv.3 | 200,000,000 - 499,999,999 |
| Lv.4 | 500,000,000 - 999,999,999 |
| Lv.5 | 1,000,000,000+ |

## 캐릭터

| 캐릭터 | 표시 이름 | 메뉴 막대 프레임 | Pet 탭 프레임 |
| --- | --- | ---: | ---: |
| Seal | 물범 말랑이 | 6 | 6 |
| Cat | 고양 말랑이 | 2 | 2 |

선택한 캐릭터, 메뉴 막대 표시 모드, 새로고침 간격, 알림 설정, backoff 상태, 캐시된 플랜명, 최신 사용량 캐시는 로컬에 저장됩니다.

## 개인정보와 보안

- ClaudePet은 Claude Code가 로컬에 저장한 동일한 OAuth 로그인을 읽습니다.
- Anthropic API 키를 요구하거나 저장하지 않습니다.
- 앱 설정과 마지막으로 성공한 사용량 스냅샷만 로컬에 저장합니다.
- 로컬 저널 파싱은 사용자의 Mac 안에서만 수행됩니다.
- 네트워크 요청은 위에 나열한 Anthropic 사용량 및 계정 엔드포인트로 제한됩니다.
- 앱은 sandbox를 사용하지 않습니다. `~/.claude` 파일과 Claude Code Keychain 항목에 접근해야 하기 때문입니다.

## 문제 해결

### OAuth 토큰 없음

다음을 실행하세요.

```bash
claude login
```

그 뒤 ClaudePet Settings를 열고 Authentication이 `Connected`인지 확인하세요.

### Rate Limited

팝오버에 표시되는 다음 재시도 시간까지 기다리세요. 수동 새로고침을 반복해도 cooldown을 우회하지 못하며, upstream rate limit이 더 오래 지속될 수 있습니다.

### Stats가 비어 있음

Stats는 `~/.claude/projects` 아래의 로컬 Claude Code 저널 파일이 필요합니다. Claude Code가 assistant 사용량 레코드를 기록한 뒤 표시됩니다.

### 캐시된 사용량이 오래되어 보임

API를 사용할 수 없을 때 ClaudePet은 마지막으로 성공한 사용량 스냅샷을 계속 보여줍니다. 캐시 모드에서는 팝오버 상태 표시가 주황색으로 바뀝니다.

## 개발 참고

- 앱 진입점: `ClaudePet/ClaudePetApp.swift`
- 공유 상태와 폴링: `ClaudePet/PetManager.swift`
- OAuth 사용량/계정 API 클라이언트: `ClaudePet/UsageAPIClient.swift`
- Claude Code 토큰 로딩: `ClaudePet/AuthLoader.swift`
- JSONL 저널 파싱: `ClaudePet/JournalLoader.swift`
- 메뉴 막대 UI: `ClaudePet/MenuBarView.swift`
- 팝오버 탭과 캐릭터 선택: `ClaudePet/PopoverView.swift`
- 분석 UI: `ClaudePet/AnalyticsView.swift`
- 설정 UI: `ClaudePet/SettingsView.swift`

이 프로젝트는 외부 패키지 의존성이 없으며, 현재 XCTest 타깃은 없습니다.

## 라이선스

MIT. [LICENSE](LICENSE)를 참고하세요.
