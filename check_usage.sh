#!/bin/bash
# check_usage.sh — ClaudePet API 응답 확인용
# 사용법: bash check_usage.sh

set -e

# 1. Keychain에서 토큰 추출 (Claude Code-credentials)
RAW=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
if [ -z "$RAW" ]; then
  echo "❌ Keychain에서 'Claude Code-credentials'를 찾을 수 없습니다."
  echo "   → 'claude login' 후 다시 시도하세요."
  exit 1
fi

TOKEN=$(echo "$RAW" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data['claudeAiOauth']['accessToken'])
" 2>/dev/null)

if [ -z "$TOKEN" ]; then
  echo "❌ accessToken 파싱 실패. credentials JSON 구조:"
  echo "$RAW" | python3 -m json.tool
  exit 1
fi

echo "✅ 토큰 로드 성공: ${TOKEN:0:20}..."
echo ""

# 2. API 호출
echo "→ GET https://api.anthropic.com/api/oauth/usage"
echo ""

HTTP_CODE=$(curl -s \
  -o /tmp/claudepet_usage.json \
  -w "%{http_code}" \
  "https://api.anthropic.com/api/oauth/usage" \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20")

echo "HTTP Status: $HTTP_CODE"
echo ""
echo "Response:"
cat /tmp/claudepet_usage.json | python3 -m json.tool

# 3. 요약
if [ "$HTTP_CODE" == "200" ]; then
  echo ""
  echo "--- 요약 ---"
  python3 - <<'PYEOF'
import json

with open("/tmp/claudepet_usage.json") as f:
    d = json.load(f)

def fmt(key, label):
    v = d.get(key)
    if v is None:
        print(f"  {label}: (null)")
    else:
        print(f"  {label}: {v['utilization']:.1f}%  (resets: {v['resets_at']})")

fmt("five_hour",        "Session (5h)  ")
fmt("seven_day",        "Weekly  (7d)  ")
fmt("seven_day_sonnet", "Sonnet  (7d)  ")
fmt("seven_day_opus",   "Opus    (7d)  ")
PYEOF
fi
