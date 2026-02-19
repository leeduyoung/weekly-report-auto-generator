# 주간보고서 자동화 시스템 — 설치 및 구성 가이드

## 시스템 개요

```
Claude Desktop (오케스트레이터)
  ├── Notion MCP (@notionhq/notion-mcp-server)
  │     └── 일일 업무일지 DB 조회 (날짜 범위 필터)
  ├── Claude 내부 처리
  │     └── 이번주 한일 + 다음주 할일 요약 생성
  └── n8n MCP (mcp-n8n)
        └── POST /webhook/weekly-report
              └── n8n 워크플로우
                    ├── 계층 구조 자동 생성 (연도 → 월 → 주 폴더)
                    ├── Markdown → HTML 변환
                    ├── Confluence 페이지 생성 (REST API 직접 호출)
                    └── 결과(페이지 URL) 반환
```

### 사전 준비 체크리스트

설치를 시작하기 전에 아래 자격 증명을 모두 발급해 두세요.

| 항목 | 발급처 | 저장할 변수명 |
|------|--------|--------------|
| Notion Integration 토큰 | notion.so/profile/integrations | `NOTION_TOKEN` |
| Notion 데이터베이스 ID | DB 페이지 URL | `NOTION_DATABASE_ID` |
| Atlassian API 토큰 | id.atlassian.com/manage-profile/security/api-tokens | `ATLASSIAN_API_TOKEN` |
| Atlassian 계정 이메일 | — | `ATLASSIAN_EMAIL` |
| Confluence 도메인 URL | — | `CONFLUENCE_BASE_URL` |
| Confluence Space Key | Confluence 사이드바 | `CONFLUENCE_SPACE_KEY` |
| Confluence 루트 페이지 ID | 대상 페이지 URL | `CONFLUENCE_ROOT_PAGE_ID` |
| n8n API Key | n8n 설치 후 생성 | `N8N_API_KEY` |

---

## 1. 자격 증명 발급

### 1-1. Notion Integration 생성

1. [notion.so/profile/integrations](https://www.notion.so/profile/integrations) 접속
2. **"새 API 통합 만들기"** 클릭
3. 이름 입력 (예: `주간보고서`) → **저장**
4. 생성된 **Internal Integration Token** (`ntn_...`) 복사

**일일 업무일지 DB에 통합 연결:**

1. Notion에서 일일 업무일지 데이터베이스 페이지 열기
2. 우상단 **"..."** 메뉴 → **"연결"** → 위에서 만든 통합 선택
3. DB URL에서 데이터베이스 ID 추출:
   ```
   https://www.notion.so/{workspace}/{database_id}?v=...
                                      ↑ 이 부분 (32자리 문자열)
   ```

> **참고**: Notion DB에 날짜(Date) 속성이 있어야 날짜 범위 필터링이 가능합니다. 없으면 추가하세요.

### 1-2. Atlassian API 토큰 생성

1. [id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens) 접속
2. **"API 토큰 만들기"** 클릭
3. 레이블 입력 (예: `n8n-weekly-report`) → **생성**
4. 표시된 토큰 즉시 복사 — **창을 닫으면 다시 볼 수 없습니다**

### 1-3. Confluence Space Key 및 루트 페이지 ID 확인

**Space Key:**
- Confluence 좌측 사이드바에서 공간(Space) 이름 아래 표시되는 약어
- 예: `TEAM`, `DEV`, `WIKI`
- 또는 공간 설정 → "공간 세부정보"에서 확인

**루트 페이지 ID:**
- 주간보고 계층 구조의 최상위 페이지를 열기 (예: "주간 보고 - 센터직속")
- URL에서 숫자 추출:
  ```
  https://your-domain.atlassian.net/wiki/spaces/TEAM/pages/123456789/페이지제목
                                                              ↑ 이 숫자가 Page ID
  ```
- 이 페이지 하위에 연도 → 월 → 주 폴더가 자동 생성됩니다

---

## 2. Docker로 n8n 설치 및 실행

### 2-1. Docker 설치 확인

```bash
docker --version
```

Docker가 설치되어 있지 않다면 [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) 에서 설치하세요.

### 2-2. n8n 컨테이너 실행

**포그라운드로 실행 (로그 확인용):**

```bash
docker run -it --rm \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  --env-file .env \
  docker.n8n.io/n8nio/n8n
```

**백그라운드로 실행 (데몬 모드, 권장):**

```bash
docker run -d \
  --name n8n \
  -p 5678:5678 \
  -v ~/.n8n:/home/node/.n8n \
  --env-file .env \
  --restart unless-stopped \
  docker.n8n.io/n8nio/n8n
```

> **중요**: `--env-file .env` 옵션이 있어야 n8n Code 노드에서 Confluence API 자격 증명(`process.env`)을 읽을 수 있습니다.

| 옵션 | 설명 |
|------|------|
| `-p 5678:5678` | 포트 바인딩 (호스트:컨테이너) |
| `-v ~/.n8n:/home/node/.n8n` | 워크플로우·자격 증명 영구 보존 |
| `--restart unless-stopped` | 시스템 재시작 시 자동 구동 |

처음 실행 시 이미지를 자동으로 다운로드합니다 (약 1~2분 소요).

**컨테이너 상태 확인:**

```bash
docker ps | grep n8n
```

### 2-3. n8n 초기 설정

1. 브라우저에서 `http://localhost:5678` 접속
2. 이메일과 비밀번호를 입력하여 **계정 생성**
3. 설문 단계는 건너뛰어도 됩니다

### 2-4. n8n API Key 생성

1. n8n 좌측 하단 **Settings** → **n8n API**
2. **"Create an API key"** 클릭
3. 생성된 키 복사 → 이후 `.env`의 `N8N_API_KEY`에 저장

---

## 3. n8n Confluence 워크플로우 구성

### 3-1. 워크플로우 import

1. n8n 좌측 메뉴 **Workflows** → 우상단 **"..."** → **"Import from file"**
2. 이 저장소의 `n8n/weekly-report-workflow.json` 파일 선택
3. 다음 3개 노드가 순서대로 연결되어 있는지 확인:

   ```
   Webhook Trigger → Process Report → Respond to Webhook
   ```

> **참고**: Confluence API 호출은 Code 노드에서 `process.env`로 자격 증명을 읽어 직접 수행합니다. n8n에 별도의 Confluence 자격 증명을 등록할 필요가 없습니다. 대신 Docker 실행 시 `--env-file .env` 옵션이 필요합니다 (2-2 참조).

### 3-2. 워크플로우 활성화

1. 워크플로우 우상단 토글을 **Active** 상태로 변경
2. Webhook URL 확인: `http://localhost:5678/webhook/weekly-report`

---

## 4. 환경 변수 설정

```bash
cp .env.template .env
```

`.env` 파일을 에디터로 열고 수집한 값을 입력합니다:

```bash
# Notion
NOTION_TOKEN=ntn_실제토큰값
NOTION_DATABASE_ID=실제데이터베이스ID

# Atlassian / Confluence
ATLASSIAN_EMAIL=your-email@company.com
ATLASSIAN_API_TOKEN=실제API토큰값
CONFLUENCE_BASE_URL=https://your-domain.atlassian.net/wiki
CONFLUENCE_SPACE_KEY=TEAM
CONFLUENCE_ROOT_PAGE_ID=123456789
CONFLUENCE_REPORT_PREFIX=센터직속

# n8n
N8N_HOST_URL=http://localhost:5678
N8N_API_KEY=실제n8nAPI키
```

> `.env` 파일은 `.gitignore`에 포함되어 있으므로 Git에 커밋되지 않습니다.

---

## 5. n8n 워크플로우 단독 테스트

n8n까지의 흐름이 정상 동작하는지 Claude Desktop 없이 먼저 확인합니다.

```bash
./scripts/test-webhook.sh
```

**성공 시 출력:**

```
🧪 Webhook 테스트 시작
   URL: http://localhost:5678/webhook/weekly-report

📡 HTTP Status: 200
📄 Response:
{
    "success": true,
    "pageId": "...",
    "pageUrl": "https://your-domain.atlassian.net/wiki/...",
    "title": "[테스트] 주간보고 - 2026-02-19"
}

✅ 테스트 성공! Confluence 페이지가 생성되었습니다.
```

Confluence에서 상위 페이지 하위에 `[테스트] 주간보고 - 날짜` 페이지가 생성되었는지 확인하세요.

**실패 시 체크리스트:**

| 증상 | 확인 사항 |
|------|----------|
| `Connection refused` | n8n 컨테이너가 실행 중인지 확인: `docker ps` |
| HTTP 404 | 워크플로우가 Active 상태인지, webhook 경로가 `weekly-report`인지 확인 |
| HTTP 500 / Confluence 오류 | `.env`의 Atlassian 자격 증명이 올바른지, Docker 실행 시 `--env-file .env`가 포함되어 있는지 확인 |
| `ROOT_PAGE_ID not found` | `CONFLUENCE_ROOT_PAGE_ID`가 해당 Space에 존재하는 페이지 ID인지 확인 |

---

## 6. Claude Desktop MCP 설정

Claude Desktop이 Notion과 n8n에 접근하도록 MCP 서버를 등록합니다.

### 6-1. 설정 파일 열기

```bash
open "~/Library/Application Support/Claude/claude_desktop_config.json"
```

파일이 없으면 새로 생성합니다.

### 6-2. MCP 서버 설정 추가

`config/claude_desktop_config.json`의 내용을 참조하여 아래와 같이 작성합니다:

```json
{
  "isUsingBuiltInNodeForMcp": true,
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

> 기존 `mcpServers`가 있다면 `notion`과 `n8n` 항목만 추가하세요.

### 6-3. Claude Desktop 재시작

설정 저장 후 Claude Desktop을 완전히 종료하고 다시 실행합니다.

**MCP 연결 확인:** Claude Desktop 화면 하단에 MCP 도구 아이콘이 표시되면 정상입니다.

---

## 7. Claude Desktop 프로젝트 지침 설정

### 7-1. 프로젝트 생성

1. Claude Desktop 좌측 사이드바에서 **"New Project"** 클릭
2. 프로젝트 이름 입력 (예: `주간보고서 자동화`)

### 7-2. 프로젝트 지침(Project Instructions) 설정

1. 프로젝트 설정 → **"Project Instructions"** (또는 "Set Instructions") 클릭
2. `prompts/weekly-report-prompt.md` 파일 내용을 전체 복사하여 붙여넣기
3. **`{{변수명}}` 플레이스홀더를 실제 값으로 대체:**

   | 플레이스홀더 | 대체할 값 (`.env` 참조) |
   |-------------|------------------------|
   | `{{NOTION_DATABASE_ID}}` | `NOTION_DATABASE_ID` 값 |
   | `{{CONFLUENCE_SPACE_KEY}}` | `CONFLUENCE_SPACE_KEY` 값 |

4. 저장

---

## 8. End-to-end 테스트

모든 설정이 완료되었습니다. 실제 흐름을 테스트합니다.

1. Claude Desktop에서 7단계에서 만든 **주간보고서 프로젝트** 열기
2. 아래 메시지 입력:
   ```
   이번 주 주간보고를 생성해줘
   ```
3. 다음 순서로 동작하는지 확인:
   - Notion MCP로 이번 주 일일 업무일지 조회
   - 이번주 한일 / 다음주 할일 초안 생성 및 사용자에게 제시
   - 사용자 확인 후 n8n webhook 호출
   - Confluence 페이지 생성 및 링크 반환

**자주 쓰는 명령어:**

| 입력 | 동작 |
|------|------|
| `이번 주 주간보고를 생성해줘` | 전체 흐름 실행 |
| `이번주 한일만 정리해줘` | Notion 조회 + 요약만 |
| `지난주 주간보고서 생성해줘` | 지난주 날짜 범위로 실행 |
| `Confluence에 올려줘` | 이전에 생성한 보고서를 바로 업로드 |

---

## 트러블슈팅

### n8n 컨테이너 재시작 방법

```bash
docker restart n8n
```

### n8n 로그 확인

```bash
docker logs n8n --tail 50
```

### Notion MCP 도구가 Claude Desktop에서 안 보일 때

1. `~/Library/Application Support/Claude/claude_desktop_config.json` 내용 재확인
2. JSON 문법 오류 여부 확인 (괄호, 따옴표)
3. Claude Desktop 재시작

### n8n MCP 도구가 webhook을 호출하지 못할 때

n8n이 실행 중인지 확인:

```bash
docker ps | grep n8n
```

n8n API Key가 `.env`와 `claude_desktop_config.json` 양쪽에 동일하게 입력되어 있는지 확인합니다.
