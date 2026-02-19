import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema } from "@modelcontextprotocol/sdk/types.js";

const server = new Server(
  { name: "http-post", version: "1.0.0" },
  { capabilities: { tools: {} } }
);

server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [{
    name: "http_post",
    description: "로컬 서버에 HTTP POST 요청을 보냅니다",
    inputSchema: {
      type: "object",
      properties: {
        url: { type: "string", description: "요청할 URL" },
        body: { type: "object", description: "전송할 JSON body" }
      },
      required: ["url", "body"]
    }
  }]
}));

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { url, body } = request.params.arguments;
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body)
  });
  const text = await response.text();
  return {
    content: [{
      type: "text",
      text: JSON.stringify({ status_code: response.status, body: text }, null, 2)
    }]
  };
});

const transport = new StdioServerTransport();
await server.connect(transport);