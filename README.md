# ClaudePet

ClaudePet은 macOS 메뉴바에서 Claude 사용량을 확인하고, 로컬 Claude Code 활동량을 작은 펫 UI로 보여주는 SwiftUI 앱입니다.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![SwiftUI](https://img.shields.io/badge/SwiftUI-macOS-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## 소개

이 앱은 두 가지 데이터를 함께 보여줍니다.

- Claude OAuth usage API 기반의 현재 사용량
- 로컬 `~/.claude/projects/**/*.jsonl` 기록 기반의 활동 히스토리

결과적으로 메뉴바에서는 현재 세션 사용량을 빠르게 확인할 수 있고, 팝오버에서는 최근 활동과 펫 성장 상태까지 한 번에 볼 수 있습니다.

## 현재 구현된 기능

- **메뉴바 실시간 표시**: 픽셀 펫, 세션 사용량 퍼센트, 또는 둘 다 표시
- **사용량 팝오버**: `5시간 세션`, `7일 전체`, `7일 Sonnet`, `7일 Opus` 진행률 표시
- **자동 새로고침**: `Off`, `1분`, `2분`, `5분`, `10분` 선택 가능
- **수동 새로고침**: 팝오버에서 즉시 재조회
- **로컬 알림**: 세션 사용량이 지정 임계값 이상일 때 경고 알림
- **활동 히트맵**: 최근 35일 토큰 활동량 시각화
- **펫 성장 시스템**: 이번 달 누적 토큰 기준 레벨 1~5 성장
- **펫 선택**: 노랑 말랑이, 고양 말랑이, 용 말랑이 선택
- **인증 상태 확인**: credentials 파일 또는 Keychain에서 로그인 상태 감지
- **API 보호 로직**: 최소 호출 간격, 중복 요청 방지, 429 백오프 처리

## 화면 구성

- **Menu Bar**: 펫 애니메이션과 세션 사용량 표시
- **Usage 탭**: Claude OAuth 사용량과 다음 리셋 시점 표시
- **Activity 탭**: 최근 35일 히트맵과 누적 토큰 요약
- **Pet 탭**: 현재 레벨, 상태 메시지, 오늘/이번 달 토큰 확인
- **Settings 뷰**: 인증 상태, 자동 새로고침, 알림 임계값, 메뉴바 표시 모드 설정

## 동작 방식

### 1. Claude 인증 정보 읽기

ClaudePet은 아래 순서로 OAuth 토큰을 찾습니다.

1. `~/.claude/.credentials.json`
2. macOS Keychain의 `Claude Code-credentials`

즉, 먼저 `claude login`이 완료되어 있어야 합니다.

### 2. 사용량 데이터 조회

주 데이터 소스:

- `GET https://api.anthropic.com/api/oauth/usage`
- 헤더: `Authorization: Bearer <token>`
- 헤더: `anthropic-beta: oauth-2025-04-20`

이 API 응답에서 다음 값을 읽습니다.

- `five_hour`
- `seven_day`
- `seven_day_sonnet`
- `seven_day_opus`

### 3. 로컬 활동 데이터 집계

보조 데이터 소스:

- `~/.claude/projects/**/*.jsonl`

여기서 Claude Code 세션의 `input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`를 합산해 최근 활동과 월간 성장 수치를 계산합니다.

## 요구사항

- macOS 13 이상
- Xcode 15 이상
- Claude Code 로그인 완료

## 실행 방법

```bash
git clone https://github.com/Jjiggu/ClaudePet.git
cd ClaudePet
open ClaudePet.xcodeproj
```

Xcode에서 `ClaudePet` 스킴으로 실행하면 됩니다.

`claude login`이 아직 안 되어 있다면 먼저 아래를 실행하세요.

```bash
npm install -g @anthropic-ai/claude-code
claude login
```

## 기술 스택

- SwiftUI
- Swift Concurrency (`async/await`)
- macOS MenuBarExtra
- 외부 의존성 없음

## 프로젝트 구조

```text
ClaudePetApp.swift      앱 진입점, MenuBarExtra 구성
PetManager.swift        사용량 조회, 상태 관리, 폴링, 알림, 레벨 계산
AuthLoader.swift        credentials 파일 / Keychain 토큰 로딩
JournalLoader.swift     Claude Code JSONL 집계
MenuBarView.swift       메뉴바 상태 표시
PopoverView.swift       팝오버 루트와 탭 UI
AnalyticsView.swift     35일 활동 히트맵
SettingsView.swift      설정 화면
AnimatedPetView.swift   픽셀 펫 애니메이션
```

## 참고

- [Claude God](https://github.com/Lcharvol/Claude-God): OAuth usage API 연동 방식 참고
- [TokenEater](https://github.com/AThevon/TokenEater): 경량 macOS 유틸리티 구조 참고
- [RunCat](https://kyome.io/runcat/): 메뉴바 캐릭터 UX 컨셉 참고

## 라이선스

MIT
