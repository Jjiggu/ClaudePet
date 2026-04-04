# ClaudePet — MVP 개발 컨텍스트

## 프로젝트 개요
맥 상태바에서 Claude Pro/Max 토큰 사용량을 모니터링하는 앱.
토큰 사용량에 따라 닭 이모지 캐릭터가 성장하는 다마고치 컨셉.
(추후 픽셀아트 캐릭터로 교체 예정, MVP는 이모지로 대체)

## 타겟 유저
Claude Pro / Max 구독자 (API 키 사용자 아님)

## 기술 스택
- Swift 5.9+, SwiftUI, macOS 13+
- 외부 의존성 없음 (Zero dependencies)
- Xcode 15+

## 데이터 소스
**1순위: OAuth API**
GET https://api.anthropic.com/api/oauth/usage
Authorization: Bearer <oauth_token>
anthropic-beta: oauth-2025-04-20
→ 5시간 세션 / 7일 누적 / 소네트 주간 / 오퍼스 주간 쿼터 반환

**2순위: JSONL 파싱 (보조)**
~/.claude/projects/**/*.jsonl
→ Claude Code 세션의 input/output 토큰 기록

토큰 로딩 우선순위: ~/.claude/.credentials.json → macOS Keychain

## 캐릭터 단계 (세션 % 기준)
- 🥚 알: 0~20%
- 🐣 부화: 20~40%
- 🐥 병아리: 40~60%
- 🐓 닭: 60~80%
- 🔥 과부하: 80~100%

## 파일 구조 (5개)
ClaudePetApp.swift   — 앱 진입점, MenuBarExtra
PetManager.swift     — OAuth 호출 + 상태관리 (핵심 로직)
AuthLoader.swift     — Keychain/파일 토큰 로딩
MenuBarView.swift    — 상태바 레이블
PopoverView.swift    — 클릭 시 팝오버 UI

## RAM 최적화 원칙 (RunCat 수준 목표: 20~30MB)
- Timer 대신 Task.sleep (suspend 가능)
- URLSession.shared 재사용 (전용 세션 생성 금지)
- struct 값 타입 우선 (class 최소화)
- 폴링 주기: 5분 (API 특성상 충분)
- Swift Concurrency (async/await) 사용, GCD 사용 금지
- 팝오버 닫히면 뷰 파괴 (항상 렌더링 금지)
- LSUIElement = true (Dock 아이콘 숨김)

## 레퍼런스 프로젝트 (참고용)
- Claude God: https://github.com/Lcharvol/Claude-God (MIT)
  → OAuth API 연동 방식, AuthManager.swift, UsageManager.swift 참고
- TokenEater: https://github.com/AThevon/TokenEater (MIT)
  → 경량 아키텍처, Keychain 읽기 방식 참고

## MVP 범위 (이것만 만들면 됨)
✅ 상태바 아이콘: 이모지 + 세션 %
✅ 클릭 팝오버: 4개 프로그레스바 (세션/주간/소네트/오퍼스)
✅ 리셋 카운트다운
✅ 5분 자동 새로고침
✅ 수동 새로고침 버튼
✅ 에러 상태 표시 (claude login 안 된 경우)

## ⚠️ 알려진 버그 & 수정 이력

### [2026-04-04] 사용량 미표시 반복 버그 (rate limit 누적)

**증상**: 앱 실행 후 사용량이 빈 화면으로 표시되거나 "Rate limited" 에러

**근본 원인 1 — @Published didSet 이중 발동**
Swift의 `@Published` 프로퍼티는 `init()` 내 할당 시에도 `didSet`이 발동됨.
`refreshInterval`의 `didSet`이 `startPolling()`을 호출하므로, 앱 실행마다
API 호출이 2회 연속 발생 (didSet → startPolling #1, init 마지막 → startPolling #2).
→ **수정**: `isInitialized` 플래그로 init 중 didSet 무시

**근본 원인 2 — 429 시 backoff 없음**
rate limit 응답을 받아도 동일 간격(5분)으로 계속 재시도 → 누적으로 limit 악화.
→ **수정**: 429 시 `rateLimitBackoff` 2배 증가 (60s → 120s → … → 1800s), 성공 시 리셋

**근본 원인 3 — 최소 요청 간격 없음**
수동 새로고침 + 자동 폴링이 동시에 발생 가능했음.
→ **수정**: `minFetchInterval = 60s` + `lastFetchTime` 추적으로 최소 60초 간격 보장

**API 특성 주의사항**
- `GET /api/oauth/usage`는 계정당 엄격한 rate limit 존재 (정확한 한도 미공개)
- `Retry-After: 0` 헤더가 붙어도 실제 제한은 수십 분 이상 지속될 수 있음
- 디버깅 목적으로도 직접 API 호출 반복 금지 (check_usage.sh 최소화)

## MVP 제외 항목
❌ JSONL 히스토리 차트
❌ 알림(Notification)
❌ 다중 계정
❌ 설정 화면
❌ 실제 픽셀아트 캐릭터
