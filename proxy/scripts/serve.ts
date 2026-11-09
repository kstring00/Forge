// The proxy on your Mac, for testing a branch in the iPhone simulator before
// it is merged and deployed. The same handlers Vercel runs, on
// http://localhost:8787. Reads ANTHROPIC_API_KEY and FORGE_PROXY_TOKEN from
// the environment (see the PR's "How to run" steps).
//
//   set -a; source .env; set +a
//   npm run serve
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";

const missing = ["ANTHROPIC_API_KEY", "FORGE_PROXY_TOKEN"].filter((k) => !process.env[k]?.trim());
if (missing.length) {
  console.error(`Missing ${missing.join(" and ")}. In this Terminal window run:\n\n  set -a; source .env; set +a\n\nthen npm run serve again. (.env holds both lines; see the PR.)`);
  process.exit(1);
}
process.env.FORGE_REQUESTS_PER_MINUTE ||= "1000";

const { default: action } = await import("../api/action.js");
const { default: research } = await import("../api/research.js");
const { default: health } = await import("../api/health.js");
const routes: Record<string, (req: never, res: never) => unknown> = {
  "/": health, "/api/health": health, "/api/action": action, "/api/research": research,
};

function adapt(res: ServerResponse) {
  return {
    statusCode: 200,
    status(code: number) { this.statusCode = code; return this; },
    setHeader(k: string, v: string) { res.setHeader(k, v); },
    json(body: unknown) {
      res.writeHead(this.statusCode, { "content-type": "application/json" });
      res.end(JSON.stringify(body));
    },
  };
}

const server = createServer((req: IncomingMessage, res: ServerResponse) => {
  const path = (req.url ?? "/").split("?")[0];
  const handler = routes[path];
  if (!handler) { res.writeHead(404); res.end(); return; }
  let raw = "";
  req.on("data", (c) => (raw += c));
  req.on("end", async () => {
    let body: unknown = undefined;
    try { body = raw ? JSON.parse(raw) : undefined; } catch { body = raw; }
    const started = Date.now();
    await handler({ method: req.method, headers: req.headers, body, url: req.url } as never, adapt(res) as never);
    console.log(`${req.method} ${path} ${res.statusCode} ${((Date.now() - started) / 1000).toFixed(1)}s`);
  });
});
server.requestTimeout = 0;
const port = Number(process.env.PORT ?? 8787);
server.listen(port, () => {
  console.log(`Hunch proxy for testing is running at http://localhost:${port}\nLeave this window open while you test. Press Control-C to stop it.`);
});
