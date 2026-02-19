#!/bin/bash
# n8n 시작 스크립트
# 사용법: ./scripts/start-n8n.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# .env 파일 로드
if [ -f "$PROJECT_DIR/.env" ]; then
  echo "📦 .env 파일 로드 중..."
  set -a
  source "$PROJECT_DIR/.env"
  set +a
else
  echo "⚠️  .env 파일이 없습니다. .env.template을 복사하여 설정하세요:"
  echo "   cp .env.template .env"
  exit 1
fi

# n8n 설치 확인
if ! command -v n8n &> /dev/null; then
  echo "📥 n8n이 설치되어 있지 않습니다. 설치 중..."
  npm install -g n8n
fi

echo "🚀 n8n 시작 중... (http://localhost:5678)"
echo "   워크플로우 import: n8n/weekly-report-workflow.json"
echo "   종료: Ctrl+C"
echo ""

n8n start
