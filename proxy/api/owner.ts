import type { VercelRequest, VercelResponse } from "@vercel/node";
import { createHmac, timingSafeEqual } from "node:crypto";
import { config } from "../lib/env.js";
import { HttpError, sendError } from "../lib/http.js";
import { isOwnerSecret } from "../lib/owner.js";
import { ownerReport } from "../lib/owner-report.js";
import { dashboardPage, loginPage } from "../lib/owner-page.js";
import { setCredit } from "../lib/credit.js";
import { store } from "../lib/store.js";

/// GET /owner — the owner's dashboard: devices, checks, spend, credit.
/// POST /owner — sign in with FORGE_OWNER_SECRET, save a credit balance, sign out.
/// `GET /owner?format=json` with the secret as a bearer token returns the same numbers.
///
/// Signing in sets a cookie that proves the secret was shown, without holding
/// it: an expiry and an HMAC of that expiry keyed by the secret. Changing the
/// secret on Vercel signs every browser out.

const cookieName = "hunch_owner";
const thirtyDays = 30 * 86_400;

function sign(value: string): string {
  return createHmac("sha256", config.ownerSecret).update(value).digest("base64url");
}

export function sessionCookie(now = Date.now()): string {
  const expires = String(Math.floor(now / 1000) + thirtyDays);
  return `${expires}.${sign(`owner:${expires}`)}`;
}

export function validSession(cookie: string | undefined, now = Date.now()): boolean {
  if (!cookie || !config.ownerSecret) return false;
  const [expires, mac] = cookie.split(".");
  if (!expires || !mac || !/^\d+$/.test(expires) || Number(expires) * 1000 < now) return false;
  const expected = Buffer.from(sign(`owner:${expires}`)), given = Buffer.from(mac);
  return expected.length === given.length && timingSafeEqual(expected, given);
}

/// Ties a form to the session it was served in, so another site cannot post it.
export function formToken(cookie: string): string { return sign(`form:${cookie}`).slice(0, 32); }

function readCookie(req: VercelRequest): string | undefined {
  const header = req.headers.cookie ?? "";
  for (const part of header.split(";")) {
    const [k, ...v] = part.trim().split("=");
    if (k === cookieName) return v.join("=");
  }
  return undefined;
}

function field(req: VercelRequest, name: string): string {
  const body = (req as { body?: unknown }).body;
  let value: unknown;
  if (typeof body === "string") value = new URLSearchParams(body).get(name);
  else if (body && typeof body === "object") value = (body as Record<string, unknown>)[name];
  return typeof value === "string" ? value.trim() : "";
}

function html(res: VercelResponse, status: number, page: string): void {
  res.setHeader("Content-Type", "text/html; charset=utf-8");
  res.setHeader("X-Robots-Tag", "noindex, nofollow");
  res.setHeader("Referrer-Policy", "no-referrer");
  res.setHeader("X-Frame-Options", "DENY");
  res.status(status).send(page);
}

function setCookie(res: VercelResponse, value: string, maxAge: number): void {
  res.setHeader("Set-Cookie", `${cookieName}=${value}; Max-Age=${maxAge}; Path=/; HttpOnly; Secure; SameSite=Strict`);
}

/// A handful of wrong secrets a minute is a typo; more is someone guessing.
async function refuseIfGuessing(): Promise<void> {
  const minute = Math.floor(Date.now() / 60_000);
  if ((await store().incrField(`owner:tries:${minute}`, "n", 1, 120)) > 10) {
    throw new HttpError(429, "too_many_tries", "Too many attempts. Wait a minute.");
  }
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  try {
    if (!config.ownerSecret) {
      html(res, 503, loginPage("FORGE_OWNER_SECRET is not set on Vercel (it needs 16 characters or more). Add it, redeploy, then come back."));
      return;
    }

    if (req.method === "GET") {
      const bearer = (req.headers.authorization ?? "").startsWith("Bearer ") ? (req.headers.authorization as string).slice(7).trim() : "";
      if (bearer) {
        if (!isOwnerSecret(bearer)) throw new HttpError(401, "unauthorized", "The owner's secret is required.");
        res.status(200).json(await ownerReport());
        return;
      }
      const cookie = readCookie(req);
      if (!validSession(cookie)) { html(res, 200, loginPage()); return; }
      html(res, 200, dashboardPage(await ownerReport(), formToken(cookie!)));
      return;
    }

    if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use GET or POST.");

    const secret = field(req, "secret");
    if (secret) {
      await refuseIfGuessing();
      if (!isOwnerSecret(secret)) { html(res, 401, loginPage("That isn't the secret.")); return; }
      setCookie(res, sessionCookie(), thirtyDays);
      res.setHeader("Location", "/owner");
      res.status(303).send("");
      return;
    }

    const cookie = readCookie(req);
    if (!validSession(cookie)) { html(res, 401, loginPage("Signed out. Enter the secret again.")); return; }
    const given = Buffer.from(field(req, "token")), expected = Buffer.from(formToken(cookie!));
    if (given.length !== expected.length || !timingSafeEqual(given, expected)) throw new HttpError(403, "bad_form", "That form is out of date. Reload the page.");

    if (field(req, "signout")) {
      setCookie(res, "", 0);
      html(res, 200, loginPage("Signed out."));
      return;
    }

    const credit = field(req, "credit").replace(/[$,\s]/g, "");
    if (credit) {
      const usd = Number(credit);
      if (!Number.isFinite(usd) || usd < 0 || usd > 100_000) {
        html(res, 400, dashboardPage(await ownerReport(), formToken(cookie!), "That balance wasn't a number. Enter dollars, like 50 or 50.00."));
        return;
      }
      await setCredit(usd);
      html(res, 200, dashboardPage(await ownerReport(), formToken(cookie!), `Balance saved: $${usd.toFixed(2)}. The count starts from now.`));
      return;
    }
    res.setHeader("Location", "/owner");
    res.status(303).send("");
  } catch (err) {
    sendError(res, err, "owner");
  }
}
