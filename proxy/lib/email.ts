// Owner alerts by email: the day's spend reaching 70% and 100% of the ceiling,
// and credit running low. Sent through Resend's HTTP API with plain fetch, so
// there is no new dependency. An alert that cannot be sent is logged and never
// fails the request that triggered it.
import { config } from "./env.js";

export interface OwnerEmail { subject: string; text: string }

type Transport = (email: OwnerEmail) => Promise<boolean>;

async function resend(email: OwnerEmail): Promise<boolean> {
  const key = config.resendApiKey;
  if (!key) {
    console.warn(JSON.stringify({ at: "alert", note: "RESEND_API_KEY is not set; alert not emailed", subject: email.subject }));
    return false;
  }
  try {
    const r = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify({ from: config.alertEmailFrom, to: [config.alertEmailTo], subject: email.subject, text: email.text }),
      signal: AbortSignal.timeout(6000),
    });
    if (!r.ok) {
      console.error(JSON.stringify({ at: "alert", note: "email refused", status: r.status, detail: (await r.text()).slice(0, 200) }));
      return false;
    }
    return true;
  } catch (err) {
    console.error(JSON.stringify({ at: "alert", note: "email failed", error: String(err).slice(0, 200) }));
    return false;
  }
}

let transport: Transport = resend;

/// Tests swap the sender for one that records.
export function useEmailTransport(t: Transport | null): void { transport = t ?? resend; }

export async function sendOwnerEmail(email: OwnerEmail): Promise<boolean> {
  console.log(JSON.stringify({ at: "alert", subject: email.subject }));
  try { return await transport(email); } catch { return false; }
}
