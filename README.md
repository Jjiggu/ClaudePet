# ClaudePet 🐾

macOS 메뉴바에서 Claude Pro/Max 사용량을 모니터링하는 다마고치 앱.
사용량에 따라 픽셀아트 말랑이 캐릭터가 반응하고 성장합니다.

![macOS](https://img.shields.io/badge/macOS-13%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## 기능

- **실시간 사용량** — 5시간 세션 / 7일 주간 / 소네트 / 오퍼스 쿼터를 진행바로 표시
- **추가 사용량** — 한도 초과 과금(Extra Usage) 잔액 및 진행률 표시
- **말랑이 캐릭터** — 세션 사용량에 따라 애니메이션 속도가 빨라지는 RunCat 스타일
- **펫 성장 시스템** — 월간 토큰 누적량으로 레벨 1~5 성장 (JSONL 기반)
- **활동 히트맵** — GitHub 스타일 35일 토큰 사용 히트맵 + 주간 추세
- **캐릭터 선택** — 물범 말랑이 🦭 / 고양 말랑이 🐾
- **메뉴바 표시 옵션** — 아이콘만 / 사용량 % 만 / 둘 다
- **자동 새로고침** — 1·2·5·10분 주기 또는 끄기
- **사용량 알림** — 지정 임계값(50~95%) 도달 시 로컬 알림

## 스크린샷

| 메뉴바 | Usage 탭 | Pet 탭 | Stats 탭 |
|--------|---------|--------|---------|
| 말랑이 + 사용량 % | 4개 쿼터 진행바 + 리셋 타이머 | 레벨·컨디션·토큰 현황 | 35일 히트맵 + 주간 추세 |

## 설치

**요구사항**: macOS 13 (Ventura) 이상 · Xcode 15 이상 · Claude Pro/Max 구독

```bash
git clone https://github.com/Jjiggu/ClaudePet.git
cd ClaudePet
open ClaudePet.xcodeproj
```

Xcode에서 `⌘R`로 실행.

**인증**: Claude CLI로 로그인하면 ClaudePet이 자동으로 토큰을 감지합니다.

```bash
npm install -g @anthropic-ai/claude-code
claude login
```

로그인 후 `~/.claude/.credentials.json` 또는 macOS Keychain에 토큰이 저장됩니다.

## 캐릭터 컨디션 (5시간 세션 기준)

| 컨디션 | 범위 | 대사 |
|--------|------|------|
| 휴식중 | 0~1% | 조용히 쉬고 있어요 |
| 안정적 | 1~20% | 아직 여유 있어요 |
| 시동중 | 20~40% | 슬슬 텐션이 올라와요 |
| 집중중 | 40~60% | 집중해서 달리는 중이에요 |
| 과열직전 | 60~100% | 오늘은 정말 빡세게 달렸어요 |

## 펫 레벨 (월간 누적 토큰 기준)

| 레벨 | 토큰 |
|------|------|
| Lv.1 | 0 ~ 50만 |
| Lv.2 | 50만 ~ 200만 |
| Lv.3 | 200만 ~ 500만 |
| Lv.4 | 500만 ~ 1000만 |
| Lv.5 | 1000만+ |

## 기술 스택

- Swift 5.9+ / SwiftUI / macOS 13+
- 외부 의존성 없음
- Swift Concurrency (async/await) — GCD 미사용
- RAM 목표: ~20~30MB

## 데이터 소스

| 소스 | 용도 |
|------|------|
| `GET api.anthropic.com/api/oauth/usage` | 실시간 쿼터 (세션·주간·소네트·오퍼스·추가사용량) |
| `~/.claude/projects/**/*.jsonl` | 일별·월별 토큰 집계, 레벨 계산 |

## 레퍼런스

- [Claude God](https://github.com/Lcharvol/Claude-God) (MIT) — OAuth API 연동 방식
- [TokenEater](https://github.com/AThevon/TokenEater) (MIT) — 경량 아키텍처
- [RunCat](https://kyome.io/runcat/) — 메뉴바 애니메이션 컨셉

## 라이선스

MIT
