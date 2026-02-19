# 주간보고서 자동화 시스템

Notion 일일 업무일지를 기반으로 주간보고서를 자동 생성하여 Confluence에 업로드하는 시스템입니다.

## 동작 방식

```
사용자: "주간보고서 생성해줘"
         │
         v
┌─────────────────────────────────────────────────────┐
│  Claude Desktop                                     │
│                                                     │
│  1. Notion MCP로 이번 주 일일 업무일지 조회          │
│  2. AI가 보고서 초안 생성 (계획/한일/차주계획/이슈)   │
│  3. 사용자 검토 및 수정                              │
│  4. n8n MCP로 webhook 호출                          │
│                                                     │
└──────────────────────┬──────────────────────────────┘
                       │ POST /webhook/weekly-report
                       v
┌─────────────────────────────────────────────────────┐
│  n8n Workflow                                       │
│                                                     │
│  1. Confluence 폴더 계층 자동 생성 (연도/월/주)      │
│  2. Markdown → Confluence HTML 변환                 │
│  3. Confluence REST API로 페이지 생성               │
│                                                     │
└──────────────────────┬──────────────────────────────┘
                       │
                       v
┌─────────────────────────────────────────────────────┐
│  Confluence                                         │
│                                                     │
│  주간 보고 - 센터직속 (루트)                         │
│    └── 센터직속 2026 (연도 폴더)                     │
│          └── 센터직속 2026-02 (월 폴더)              │
│                └── 센터직속 2026-02-09 ~ ... (주)    │
│                      └── 이두영 2026-02-09 ~ 02-13  │
│                                                     │
└─────────────────────────────────────────────────────┘
```

## 빠른 시작

### 1. 환경 변수 설정

```bash
cp .env.template .env
# .env 파일을 편집하여 실제 자격 증명 입력
```

### 2. n8n 실행 (Docker)

```bash
docker run -d \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  --env-file .env \
  --restart unless-stopped \
  docker.n8n.io/n8nio/n8n
```

### 3. n8n 워크플로우 import

1. `http://localhost:5678` 접속
2. Workflows > Import from file > `n8n/weekly-report-workflow.json` 선택
3. 워크플로우 활성화 (Active 토글)

### 4. Claude Desktop MCP 설정

`~/Library/Application Support/Claude/claude_desktop_config.json`에 MCP 서버 추가:

```json
{
  "mcpServers": {
    "notion": {
      "command": "npx",
      "args": ["-y", "@notionhq/notion-mcp-server"],
      "env": {
        "NOTION_TOKEN": "ntn_실제토큰값"
      }
    },
    "n8n": {
      "command": "npx",
      "args": ["-y", "mcp-n8n"],
      "env": {
        "N8N_HOST_URL": "http://localhost:5678",
        "N8N_API_KEY": "실제n8nAPI키"
      }
    }
  }
}
```

### 5. Claude Desktop 프로젝트 지침 등록

1. Claude Desktop에서 프로젝트 생성
2. Project Instructions에 `prompts/weekly-report-prompt.md` 내용 붙여넣기
3. Claude Desktop 재시작

### 6. 사용

Claude Desktop에서:

```
주간보고서 생성해줘
```

## 프로젝트 구조

```
weekly-report/
├── .env.template                  # 환경 변수 템플릿
├── config/
│   └── claude_desktop_config.json # Claude Desktop MCP 설정 레퍼런스
├── n8n/
│   └── weekly-report-workflow.json # n8n 워크플로우 (import용)
├── prompts/
│   └── weekly-report-prompt.md    # Claude Desktop 프로젝트 지침
├── scripts/
│   ├── mcp-scripts/
│   │   ├── http-post-mcp.mjs      # HTTP POST 커스텀 MCP 서버
│   │   └── postgres-mcp.sh        # PostgreSQL MCP Docker 래퍼
│   ├── start-n8n.sh               # n8n 로컬 실행 스크립트
│   └── test-webhook.sh            # webhook 테스트 스크립트
├── CLAUDE.md                      # Claude Code 개발 가이드
└── GUIDE.md                       # 상세 설치 가이드
```

## 환경 변수

| 변수 | 설명 |
|------|------|
| `NOTION_TOKEN` | Notion Integration 토큰 |
| `NOTION_DATABASE_ID` | 일일 업무일지 데이터베이스 ID |
| `ATLASSIAN_EMAIL` | Atlassian 계정 이메일 |
| `ATLASSIAN_API_TOKEN` | Atlassian API 토큰 |
| `CONFLUENCE_BASE_URL` | Confluence 도메인 (예: `https://xxx.atlassian.net/wiki`) |
| `CONFLUENCE_SPACE_KEY` | Confluence Space Key |
| `CONFLUENCE_ROOT_PAGE_ID` | 주간보고 계층 구조 루트 페이지 ID |
| `CONFLUENCE_REPORT_PREFIX` | 폴더명 접두어 (예: `센터직속`) |
| `REPORT_AUTHOR_NAME` | 보고서 작성자 이름 |
| `N8N_HOST_URL` | n8n 호스트 URL |
| `N8N_API_KEY` | n8n API Key |

## 사용 가능한 명령어

| 입력 | 동작 |
|------|------|
| `주간보고서 생성해줘` | Notion 조회 → 보고서 생성 → 검토 → Confluence 업로드 |
| `이번주 한일만 정리해줘` | Notion 조회 → 한일 요약만 생성 |
| `다음주 할일 추천해줘` | 한일 기반 차주 계획 추천 |
| `지난주 주간보고서 생성해줘` | 지난주 날짜 범위로 전체 흐름 실행 |
| `Confluence에 올려줘` | 이전에 생성한 보고서를 바로 업로드 |

## 테스트

n8n webhook을 직접 테스트:

```bash
./scripts/test-webhook.sh
```

## 상세 설치 가이드

자격 증명 발급, Docker 설정, 트러블슈팅 등 상세 내용은 [GUIDE.md](GUIDE.md)를 참고하세요.
