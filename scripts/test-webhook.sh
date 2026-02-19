#!/bin/bash
# n8n webhook 테스트 스크립트
# 사용법: ./scripts/test-webhook.sh
#
# 사전 조건:
#   1. n8n이 실행 중이어야 합니다 (Docker 또는 ./scripts/start-n8n.sh)
#   2. weekly-report-workflow.json이 n8n에 import되어 있어야 합니다
#   3. .env에 Confluence 자격 증명이 설정되어 있어야 합니다
#      (CONFLUENCE_BASE_URL, ATLASSIAN_EMAIL, ATLASSIAN_API_TOKEN, CONFLUENCE_ROOT_PAGE_ID)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# .env 파일 로드
if [ -f "$PROJECT_DIR/.env" ]; then
  set -a
  source "$PROJECT_DIR/.env"
  set +a
fi

WEBHOOK_URL="${N8N_HOST_URL:-http://localhost:5678}/webhook/weekly-report"
SPACE_KEY="${CONFLUENCE_SPACE_KEY:-TEAM}"
AUTHOR_NAME="${REPORT_AUTHOR_NAME:-홍길동}"

# 이번 주 월요일~금요일 날짜 자동 계산 (macOS date -v 문법)
DOW=$(date +%u)  # 1=Mon, 7=Sun
MONDAY=$(date -v -"$((DOW - 1))"d +%Y-%m-%d)
FRIDAY=$(date -v -"$((DOW - 1))"d -v +4d +%Y-%m-%d)

echo "🧪 Webhook 테스트 시작"
echo "   URL: $WEBHOOK_URL"
echo "   작성자: $AUTHOR_NAME"
echo "   주간 범위: $MONDAY ~ $FRIDAY"
echo ""

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d @- <<EOF
{
  "authorName": "${AUTHOR_NAME}",
  "spaceKey": "${SPACE_KEY}",
  "weekStartDate": "${MONDAY}",
  "weekEndDate": "${FRIDAY}",
  "thisWeekPlan": "**프로젝트 A**\n- 기능 X 설계 및 개발\n- 코드 리뷰 진행",
  "thisWeekDone": "**프로젝트 A**\n- 기능 X 개발 완료\n  - API 엔드포인트 구현\n  - 단위 테스트 작성\n- 코드 리뷰 2건 완료",
  "nextWeekPlan": "**프로젝트 A**\n- 기능 X QA 및 버그 수정\n- 기능 Y 설계 착수",
  "issues": "특이사항 없음",
  "resolvedIssues": "",
  "newIssues": "",
  "leavePlan": "",
  "comments": ""
}
EOF
)

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

echo "📡 HTTP Status: $HTTP_CODE"
echo "📄 Response:"
echo "$BODY" | python3 -m json.tool 2>/dev/null || echo "$BODY"

if [ "$HTTP_CODE" = "200" ]; then
  echo ""
  echo "✅ 테스트 성공! Confluence 페이지가 생성되었습니다."
else
  echo ""
  echo "❌ 테스트 실패. HTTP 상태 코드: $HTTP_CODE"
  echo "   n8n이 실행 중인지, 워크플로우가 활성화되어 있는지 확인하세요."
fi
