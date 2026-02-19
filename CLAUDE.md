# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

주간보고서 자동화: Notion 일일 업무일지 → Claude Desktop 요약 → n8n webhook → Confluence 페이지 생성. 이 저장소는 코드 프로젝트가 아닌 **설정/워크플로우 모음**이다.

## Architecture

```
Claude Desktop (orchestrator)
  ├── Notion MCP (@notionhq/notion-mcp-server) → 일일 업무일지 DB 조회
  ├── Claude 내부 처리 → 요약 생성
  └── n8n MCP (mcp-n8n) → webhook POST 호출
        └── n8n Workflow: Webhook → Process Report (계층 생성 + MD→HTML + Confluence API) → 응답
```

## Key Files

- `n8n/weekly-report-workflow.json` — n8n에 import하는 워크플로우. Confluence API 호출은 Code 노드에서 `$env`로 자격 증명을 읽어 직접 수행
- `prompts/weekly-report-prompt.md` — Claude Desktop 프로젝트 지침. `{{변수명}}` 플레이스홀더는 `.env` 값 참조
- `config/claude_desktop_config.json` — Claude Desktop MCP 설정 레퍼런스 (실제 설정은 `~/Library/Application Support/Claude/claude_desktop_config.json`)

## Commands

```bash
./scripts/start-n8n.sh      # .env 로드 후 n8n 시작 (미설치 시 자동 설치)
./scripts/test-webhook.sh   # n8n webhook에 테스트 데이터 POST → Confluence 페이지 생성 확인
```

## NPM Package Names

- Notion MCP: `@notionhq/notion-mcp-server` (v2.1.0)
- n8n MCP: `mcp-n8n` (**주의**: 계획서에 있던 `@ahmad.soliman/mcp-n8n-server`는 존재하지 않는 패키지)

## Webhook Contract

n8n webhook (`POST /webhook/weekly-report`)이 받는 JSON:

```json
{
  "authorName": "이두영",
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

**페이지 제목**: `{authorName} {weekStartDate} ~ {weekEndDate(MM-DD)}` 형식으로 자동 생성 (예: "이두영 2026-02-09 ~ 02-13"). `title` 필드를 직접 전달하면 그 값을 사용.

**페이지 본문**: Confluence 테이블 템플릿으로 생성 — 주간 업무 테이블 (이번 주 계획 / 이번 주 한일 / 차주 계획), 이슈 테이블, 연차 계획, 하고 싶은 말.

**계층 구조**: `weekStartDate`/`weekEndDate`가 전달되면 root → 연도 → 월 → 주 폴더를 자동 생성하고 그 하위에 보고서를 생성한다. `parentPageId`를 직접 전달하면 계층 생성 없이 해당 페이지 하위에 바로 생성한다 (하위 호환).

**하위 호환**: `thisWeekContent` → `thisWeekDone`, `nextWeekContent` → `nextWeekPlan`으로 매핑됨.

## Language

프롬프트, 보고서, 사용자 대면 텍스트는 모두 한국어로 작성한다.
