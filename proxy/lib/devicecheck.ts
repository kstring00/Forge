// DeviceCheck, the fallback when App Attest is not available on a device.
// A DeviceCheck token proves a genuine Apple device running this app; it does
// not identify the device, so the app sends an install id alongside for the
// per-device limits. Validation asks Apple's server with a JWT signed by the
// DeviceCheck key from the developer account.
import { SignJWT, importPKCS8 } from "jose";
import { config } from "./env.js";
import { store } from "./store.js";

export class DeviceCheckError extends Error {
  constructor(public code: string, message: string) { super(message); }
}

export function deviceCheckConfigured(): boolean {
  return Boolean(config.appleTeamID && config.deviceCheckKeyID && config.deviceCheckPrivateKey);
}

async function jwt(): Promise<string> {
  const key = await importPKCS8(config.deviceCheckPrivateKey.replace(/\\n/g, "\n"), "ES256");
  return new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: config.deviceCheckKeyID })
    .setIssuer(config.appleTeamID)
    .setIssuedAt()
    .sign(key);
}

function host(): string {
  return config.appAttestEnvironment === "development" ? "api.development.devicecheck.apple.com" : "api.devicecheck.apple.com";
}

/// Apple keeps two bits per device per developer, across reinstalls. Bit 0 is
/// "this device has had its free first check" (decision 0027). Null when Apple
/// has never been told anything about this device.
export async function queryBits(token: string): Promise<{ bit0: boolean; bit1: boolean } | null> {
  if (!deviceCheckConfigured()) throw new DeviceCheckError("not_configured", "DeviceCheck is not configured on this proxy.");
  const res = await fetch(`https://${host()}/v1/query_two_bits`, {
    method: "POST",
    headers: { Authorization: `Bearer ${await jwt()}`, "Content-Type": "application/json" },
    body: JSON.stringify({ device_token: token, transaction_id: crypto.randomUUID(), timestamp: Date.now() }),
  });
  const text = await res.text().catch(() => "");
  if (res.status === 200) {
    if (!text.trim() || /Failed to find bit state/i.test(text)) return null;
    try {
      const j = JSON.parse(text) as { bit0?: boolean; bit1?: boolean };
      return { bit0: Boolean(j.bit0), bit1: Boolean(j.bit1) };
    } catch { return null; }
  }
  console.error(JSON.stringify({ at: "devicecheck.query", status: res.status, body: text.slice(0, 200) }));
  throw new DeviceCheckError("query_failed", `Apple did not answer the bit query (${res.status}).`);
}

export async function updateBits(token: string, bits: { bit0: boolean; bit1: boolean }): Promise<void> {
  if (!deviceCheckConfigured()) throw new DeviceCheckError("not_configured", "DeviceCheck is not configured on this proxy.");
  const res = await fetch(`https://${host()}/v1/update_two_bits`, {
    method: "POST",
    headers: { Authorization: `Bearer ${await jwt()}`, "Content-Type": "application/json" },
    body: JSON.stringify({ device_token: token, transaction_id: crypto.randomUUID(), timestamp: Date.now(), bit0: bits.bit0, bit1: bits.bit1 }),
  });
  if (res.status !== 200) {
    const text = await res.text().catch(() => "");
    console.error(JSON.stringify({ at: "devicecheck.update", status: res.status, body: text.slice(0, 200) }));
    throw new DeviceCheckError("update_failed", `Apple did not record the bits (${res.status}).`);
  }
}

/// True when Apple accepts the token. Results are cached for a day per token
/// hash, so a device is checked with Apple once a day, not on every call.
export async function validateDeviceToken(token: string, tokenHash: string): Promise<boolean> {
  if (!deviceCheckConfigured()) throw new DeviceCheckError("not_configured", "DeviceCheck is not configured on this proxy.");
  const s = store();
  const cached = await s.get<boolean>(`devicecheck:ok:${tokenHash}`);
  if (cached) return true;
  const res = await fetch(`https://${host()}/v1/validate_device_token`, {
    method: "POST",
    headers: { Authorization: `Bearer ${await jwt()}`, "Content-Type": "application/json" },
    body: JSON.stringify({ device_token: token, transaction_id: crypto.randomUUID(), timestamp: Date.now() }),
  });
  if (res.status === 200) {
    await s.set(`devicecheck:ok:${tokenHash}`, true, 86_400);
    return true;
  }
  const text = await res.text().catch(() => "");
  console.error(JSON.stringify({ at: "devicecheck", status: res.status, body: text.slice(0, 200) }));
  return false;
}
