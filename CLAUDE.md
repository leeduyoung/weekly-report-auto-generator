# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

주간보고서 자동화: Notion 일일 업무일지 → Claude Desktop 요약 → n8n webhook → Confluence 페이지 생성. 이 저장소는 코드 프로젝트가 아닌 **설정/워크플로우 모음**이다.

## Architecture

### 전체 흐름

```
┌──────────┐       ┌──────────────────────────────────────────┐
│          │       │          Claude Desktop                  │
│  사용자   │──────>│                                          │
│          │       │  ┌────────────┐     ┌─────────────────┐  │
│          │<──────│  │ Notion MCP │     │ Claude AI 처리   │  │
│          │       │  │  (조회)    │────>│  (요약 생성)     │  │
│          │       │  └────────────┘     └────────┬────────┘  │
│          │       │                              │           │
│          │       │                     ┌────────v────────┐  │
│          │       │                     │    n8n MCP      │  │
│          │       │                     │ (webhook 호출)  │  │
│          │       │                     └────────┬────────┘  │
│          │       └──────────────────────────────┼───────────┘
└──────────┘                                      │
                                                  │ POST /webhook/weekly-report
                                                  v
┌─────────────────────────────────────────────────────────────┐
│  n8n Workflow (Docker)                                      │
│                                                             │
│  Webhook Trigger ──> Process Report (Code) ──> Respond      │
│                       │                                     │
│                       ├─ 폴더 계층 생성 (연도/월/주)          │
│                       ├─ Markdown → Confluence HTML 변환     │
│                       └─ Confluence REST API 호출            │
│                                                             │
└──────────────────────────────┬──────────────────────────────┘
                               │
                               v
┌─────────────────────────────────────────────────────────────┐
│  Confluence                                                 │
│                                                             │
│  루트 페이지                                                 │
│    └── {prefix} {year}           (폴더)                     │
│          └── {prefix} {year}-{month}     (폴더)             │
│                └── {prefix} {start} ~ {end}  (폴더)         │
│                      └── {author} {start} ~ {MM-DD} (페이지) │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 데이터 흐름 요약

```
Notion DB (일일 업무일지)
    │
    │  Notion MCP (notion_query_database)
    v
Claude Desktop ── AI 요약 ──> 보고서 초안 (이번 주 계획/한일/차주 계획/이슈)
    │
    │  사용자 검토 및 수정
    v
n8n webhook (POST)
    │
    │  Code 노드: 폴더 계층 탐색/생성 → MD→HTML → Confluence API
    v
Confluence 페이지 생성 완료
```

### 컴포넌트 역할

| 컴포넌트 | 역할 | 기술 |
|----------|------|------|
| **Claude Desktop** | 오케스트레이터. 사용자 대화, Notion 조회, 요약 생성, webhook 호출 | MCP (Model Context Protocol) |
| **Notion MCP** | Notion API를 Claude Desktop에 노출 | `@notionhq/notion-mcp-server` |
| **n8n MCP** | n8n API/webhook을 Claude Desktop에 노출 | `mcp-n8n` |
| **n8n Workflow** | Confluence 폴더 계층 생성 + MD→HTML 변환 + 페이지 생성 | Docker, Code 노드 (`$env` + `this.helpers.httpRequest()`) |
| **Confluence** | 최종 보고서 저장소 | REST API v1 |

## Key Files

| 파일 | 설명 |
|------|------|
| `n8n/weekly-report-workflow.json` | n8n import용 워크플로우. Code 노드에서 `$env`로 자격 증명을 읽어 Confluence API 직접 호출 |
| `prompts/weekly-report-prompt.md` | Claude Desktop 프로젝트 지침. 보고서 생성 절차 정의 |
| `config/claude_desktop_config.json` | Claude Desktop MCP 설정 레퍼런스 (실제: `~/Library/Application Support/Claude/claude_desktop_config.json`) |
| `scripts/start-n8n.sh` | .env 로드 후 n8n 로컬 실행 (npm global) |
| `scripts/test-webhook.sh` | n8n webhook에 테스트 데이터 POST |
| `scripts/mcp-scripts/http-post-mcp.mjs` | HTTP POST 커스텀 MCP 서버. n8n MCP 대안으로 webhook 직접 호출 가능 |
| `scripts/mcp-scripts/postgres-mcp.sh` | PostgreSQL MCP Docker 래퍼. 컨테이너 재사용 로직 포함 |
| `.env.template` | 환경 변수 템플릿 |

## Commands

```bash
./scripts/start-n8n.sh      # .env 로드 후 n8n 시작 (미설치 시 자동 설치)
./scripts/test-webhook.sh   # n8n webhook에 테스트 데이터 POST → Confluence 페이지 생성 확인
```

## NPM Package Names

- Notion MCP: `@notionhq/notion-mcp-server`
- n8n MCP: `mcp-n8n` (**주의**: `@ahmad.soliman/mcp-n8n-server`는 존재하지 않는 패키지)

## n8n 2.x Sandbox Constraints

n8n Code 노드는 샌드박스 환경에서 실행된다. 일반적인 Node.js API를 사용할 수 없다:

| 사용 불가 | 대체 방법 |
|-----------|----------|
| `process.env.VAR` | `$env.VAR` |
| `fetch()` | `this.helpers.httpRequest()` |
| `require()` | 사용 불가 (내장 모듈만 가능) |

**사용 가능**: `Buffer`, `btoa`, `this.helpers`, `$env`

**필수 환경 변수**: Docker 실행 시 `--env-file .env` + `.env`에 `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` 설정 필요

## Webhook Contract

n8n webhook (`POST /webhook/weekly-report`)이 받는 JSON:

```json
{
  "authorName": "홍길동",
  "spaceKey": "G1",
  "weekStartDate": "2026-02-09",
  "weekEndDate": "2026-02-13",
  "thisWeekPlan": "이번 주 계획 (markdown)",
  "thisWeekDone": "이번 주 한일 (markdown)",
  "nextWeekPlan": "차주 계획 (markdown)",
  "issues": "이슈 현황 (선택)",
  "resolvedIssues": "해소된 이슈 (선택)",
  "newIssues": "추가된 이슈 (선택)",
  "leavePlan": "연차 사용 계획 (선택)",
  "comments": "하고 싶은 말 (선택)"
}
```

**페이지 제목**: `{authorName} {weekStartDate} ~ {weekEndDate(MM-DD)}` 형식으로 자동 생성 (예: "홍길동 2026-02-09 ~ 02-13"). `title` 필드를 직접 전달하면 그 값을 사용.

**페이지 본문**: Confluence 테이블 템플릿으로 생성 -- 주간 업무 테이블 (이번 주 계획 / 이번 주 한일 / 차주 계획), 이슈 테이블, 연차 계획, 하고 싶은 말.

**계층 구조**: `weekStartDate`/`weekEndDate`가 전달되면 root -> 연도 -> 월 -> 주 폴더를 자동 생성하고 그 하위에 보고서를 생성한다. 모든 중간 계층은 `type: "folder"`, 최종 보고서만 `type: "page"`. `parentPageId`를 직접 전달하면 계층 생성 없이 해당 페이지 하위에 바로 생성한다 (하위 호환).

**Confluence 폴더 API 참고**: 폴더 검색은 `/content/{parentId}/child/folder` 엔드포인트를 사용해야 한다. `/content?title=`은 페이지만 검색하고 폴더는 찾지 못한다.

**하위 호환**: `thisWeekContent` -> `thisWeekDone`, `nextWeekContent` -> `nextWeekPlan`으로 매핑됨.

## Language

프롬프트, 보고서, 사용자 대면 텍스트는 모두 한국어로 작성한다.
