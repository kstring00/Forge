// Who is calling. Three doors, checked in this order:
//
// 1. App Attest: `X-Forge-Key-Id` and `X-Forge-Assertion`, an assertion over
//    SHA-256 of the exact request body. The normal door for every real device.
// 2. DeviceCheck: `X-Forge-Device-Token` and `X-Forge-Install-Id`, for the rare
//    device where App Attest is unavailable.
// 3. A developer token in `Authorization: Bearer`, from FORGE_DEV_TOKENS (or
//    the older FORGE_PROXY_TOKEN). For simulators and development builds; a
//    release build carries no token.
//
// Every door yields a DeviceIdentity the limits and the usage log key on.
import type { VercelRequest } from "@vercel/node";
import { createHash, timingSafeEqual } from "node:crypto";
import { config } from "./env.js";
import { HttpError } from "./http.js";
import { AttestError, verifyAssertion } from "./attest.js";
import { DeviceCheckError, deviceCheckConfigured, validateDeviceToken } from "./devicecheck.js";

export interface DeviceIdentity {
  /// Stable per install: the App Attest key id, the install id, or "dev:<n>".
  id: string;
  door: "appattest" | "devicecheck" | "dev";
}

function header(req: VercelRequest, name: string): string | null {
  const v = req.headers[name.toLowerCase()];
  const s = Array.isArray(v) ? v[0] : v;
  return s && s.trim() ? s.trim() : null;
}

function safeEqual(a: string, b: string): boolean {
  const x = Buffer.from(a), y = Buffer.from(b);
  return x.length === y.length && timingSafeEqual(x, y);
}

export async function requireDevice(req: VercelRequest, rawBody: Buffer): Promise<DeviceIdentity> {
  const keyId = header(req, "X-Forge-Key-Id");
  const assertion = header(req, "X-Forge-Assertion");
  if (keyId && assertion) {
    try {
      await verifyAssertion({ keyId, assertion, clientDataHash: createHash("sha256").update(rawBody).digest(), appID: config.appID });
      return { id: keyId, door: "appattest" };
    } catch (err) {
      if (err instanceof AttestError) throw new HttpError(401, `attest_${err.code}`, err.message);
      throw err;
    }
  }

  const deviceToken = header(req, "X-Forge-Device-Token");
  const installId = header(req, "X-Forge-Install-Id");
  if (deviceToken && installId) {
    if (!deviceCheckConfigured()) throw new HttpError(503, "devicecheck_not_configured", "This proxy cannot check devices yet.");
    const tokenHash = createHash("sha256").update(deviceToken).digest("hex");
    try {
      const ok = await validateDeviceToken(deviceToken, tokenHash);
      if (!ok) throw new HttpError(401, "devicecheck_rejected", "Apple did not vouch for this device.");
    } catch (err) {
      if (err instanceof DeviceCheckError) throw new HttpError(503, `devicecheck_${err.code}`, err.message);
      throw err;
    }
    if (!/^[A-Za-z0-9_-]{8,64}$/.test(installId)) throw new HttpError(400, "bad_install_id", "The install id is malformed.");
    return { id: `install:${installId}`, door: "devicecheck" };
  }

  const auth = req.headers.authorization ?? "";
  const bearer = auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
  if (bearer) {
    const tokens = config.devTokens;
    const index = tokens.findIndex((t) => safeEqual(t, bearer));
    if (index >= 0) return { id: `dev:${index + 1}`, door: "dev" };
    throw new HttpError(401, "unauthorized", "Missing or invalid proxy token.");
  }

  throw new HttpError(401, "unauthorized", "This proxy serves the Hunch app only. No device proof was sent.");
}

/// The exact bytes of the body, which the assertion signs. Vercel's parser is
/// turned off on the routes that need this.
export async function readRawBody(req: VercelRequest): Promise<Buffer> {
  if (Buffer.isBuffer(req.body)) return req.body;
  if (typeof req.body === "string") return Buffer.from(req.body, "utf8");
  if (req.body && typeof req.body === "object" && Object.keys(req.body).length) return Buffer.from(JSON.stringify(req.body), "utf8");
  const chunks: Buffer[] = [];
  for await (const chunk of req) chunks.push(typeof chunk === "string" ? Buffer.from(chunk) : chunk);
  return Buffer.concat(chunks);
}

export function parseJSONBody<T>(raw: Buffer): T {
  if (!raw.length) throw new HttpError(400, "bad_request", "Body must be JSON.");
  try { return JSON.parse(raw.toString("utf8")) as T; } catch { throw new HttpError(400, "bad_request", "Body is not valid JSON."); }
}
