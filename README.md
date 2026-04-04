# ClaudePet 🐾

macOS 메뉴바에서 Claude Pro/Max 토큰 사용량을 모니터링하는 앱.
토큰 사용량에 따라 픽셀아트 말랑이 캐릭터가 반응하는 다마고치 컨셉.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## 스크린샷

| 메뉴바 | 사용량 팝오버 | 펫 탭 |
|--------|-------------|-------|
| 상태바에 말랑이 + 사용량 % | 세션/주간 사용량 진행바 | 레벨 & 성장 현황 |

## 기능

- **실시간 사용량 모니터링** — Claude OAuth API로 5시간 세션 / 7일 주간 사용량 표시
- **말랑이 캐릭터** — 사용량에 따라 애니메이션 속도 변화 (RunCat 스타일)
- **펫 성장 시스템** — JSONL 히스토리 기반 월간 토큰으로 레벨 1~5 성장
- **자동 새로고침** — 1분 / 2분 / 5분 / 10분 주기 선택
- **사용량 알림** — 지정 임계값(50~95%) 도달 시 로컬 알림
- **메뉴바 표시 옵션** — 아이콘만 / 사용량만 / 둘 다 선택 가능
- **말랑이 선택** — 노랑 말랑이 / 고양 말랑이 / 용 말랑이

## 캐릭터 단계 (세션 사용량 기준)

| 단계 | 범위 | 상태 |
|------|------|------|
| 🥚 알 | 0~20% | 대기중... |
| 🐣 부화 | 20~40% | 여유롭네~ |
| 🐥 병아리 | 40~60% | 열심히 일중! |
| 🐓 닭 | 60~80% | 바쁘다 바빠... |
| 🔥 과부하 | 80~100% | 과부하! |

## 설치

### 요구사항

- macOS 13 (Ventura) 이상
- Xcode 15 이상
- Claude Pro 또는 Max 구독 + `claude login` 완료

### 빌드

```bash
git clone https://github.com/Jjiggu/ClaudePet.git
cd ClaudePet
open ClaudePet.xcodeproj
```

Xcode에서 `⌘R` 로 실행.

### 인증 설정

Claude CLI가 설치되어 있어야 함:

```bash
# Claude CLI 설치
npm install -g @anthropic-ai/claude-code

# 로그인
claude login
```

로그인 후 `~/.claude/.credentials.json` 또는 macOS Keychain에 토큰이 저장됨. ClaudePet이 자동으로 감지.

## 기술 스택

- **Swift 5.9+** / **SwiftUI** / **macOS 13+**
- 외부 의존성 없음 (Zero dependencies)
- Swift Concurrency (async/await) — GCD 미사용
- RAM 목표: ~20~30MB (RunCat 수준)

## 데이터 소스

1. **OAuth API** (주): `GET https://api.anthropic.com/api/oauth/usage`
   - 5시간 세션 / 7일 누적 / 소네트 주간 / 오퍼스 주간 쿼터 반환
2. **JSONL 파싱** (보조): `~/.claude/projects/**/*.jsonl`
   - Claude Code 세션의 input/output 토큰 → 일별/월별 사용량 집계

## 레퍼런스

- [Claude God](https://github.com/Lcharvol/Claude-God) (MIT) — OAuth API 연동 방식 참고
- [TokenEater](https://github.com/AThevon/TokenEater) (MIT) — 경량 아키텍처 참고
- [RunCat](https://kyome.io/runcat/) — UI/UX 컨셉 참고

## 라이선스

MIT
