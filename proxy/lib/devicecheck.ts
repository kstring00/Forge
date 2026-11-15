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

/// True when Apple accepts the token. Results are cached for a day per token
/// hash, so a device is checked with Apple once a day, not on every call.
export async function validateDeviceToken(token: string, tokenHash: string): Promise<boolean> {
  if (!deviceCheckConfigured()) throw new DeviceCheckError("not_configured", "DeviceCheck is not configured on this proxy.");
  const s = store();
  const cached = await s.get<boolean>(`devicecheck:ok:${tokenHash}`);
  if (cached) return true;
  const host = config.appAttestEnvironment === "development" ? "api.development.devicecheck.apple.com" : "api.devicecheck.apple.com";
  const res = await fetch(`https://${host}/v1/validate_device_token`, {
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
