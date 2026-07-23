/**
 * Salin ke gurubot-pwa — proxy API operator ke setup-agent di host Windows.
 * Env: OPERATOR_AGENT_URL (default http://host.docker.internal:2077)
 *      OPERATOR_AGENT_TOKEN (dari .env.docker)
 */
import { NextRequest, NextResponse } from "next/server";

const AGENT_BASE =
  process.env.OPERATOR_AGENT_URL?.replace(/\/$/, "") ||
  "http://host.docker.internal:2077";

type Params = { path?: string[] };

async function proxy(req: NextRequest, segments: string[]) {
  const sub = segments.join("/");
  const url = `${AGENT_BASE}/api/operator/${sub}${req.nextUrl.search}`;

  const headers = new Headers();
  const auth = req.headers.get("authorization");
  if (auth) headers.set("Authorization", auth);
  const token = process.env.OPERATOR_AGENT_TOKEN;
  if (!auth && token && !sub.startsWith("auth/") && sub !== "bootstrap") {
    headers.set("Authorization", `Bearer ${token}`);
  }
  const ct = req.headers.get("content-type");
  if (ct) headers.set("Content-Type", ct);

  const init: RequestInit = {
    method: req.method,
    headers,
    cache: "no-store",
  };
  if (req.method !== "GET" && req.method !== "HEAD") {
    init.body = await req.arrayBuffer();
  }

  const res = await fetch(url, init);
  const resCt = res.headers.get("content-type") || "";
  if (resCt.includes("application/json")) {
    const data = await res.json();
    return NextResponse.json(data, { status: res.status });
  }
  const buf = await res.arrayBuffer();
  return new NextResponse(buf, {
    status: res.status,
    headers: {
      "Content-Type": resCt || "application/octet-stream",
      "Content-Disposition":
        res.headers.get("content-disposition") || "attachment",
    },
  });
}

export async function GET(req: NextRequest, ctx: { params: Promise<Params> }) {
  const { path = [] } = await ctx.params;
  return proxy(req, path);
}

export async function POST(req: NextRequest, ctx: { params: Promise<Params> }) {
  const { path = [] } = await ctx.params;
  return proxy(req, path);
}
