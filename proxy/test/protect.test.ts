import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash, createSign, generateKeyPairSync } from "node:crypto";
import { encode as cborEncode } from "cbor-x";

process.env.ANTHROPIC_API_KEY = "sk-test";
process.env.APPLE_TEAM_ID = "ABCDE12345";
process.env.APP_BUNDLE_ID = "com.stringhamwebdesign.hunch";
process.env.FORGE_PROXY_TOKEN = "dev-token-0123456789abcdef";
process.env.FORGE_CHECKS_PER_DEVICE_PER_DAY = "2";
process.env.FORGE_DAILY_SPEND_USD = "1";

const { useMemoryStore } = await import("../lib/store.js");
const { parseAuthenticatorData, saveKey, sha256, verifyAssertion, uncompressedPoint, nonceFromCertificate } = await import("../lib/attest.js");
const { startCheck, recordUsage, refuseIfResting, usageFor } = await import("../lib/limits.js");
const { requireDevice } = await import("../lib/auth.js");
const { HttpError } = await import("../lib/http.js");

const appID = "ABCDE12345.com.stringhamwebdesign.hunch";

function authData(counter: number, withCredential = false, credentialId = Buffer.alloc(32, 7)): Buffer {
  const head = Buffer.alloc(37);
  sha256(Buffer.from(appID)).copy(head, 0);
  head[32] = withCredential ? 0x41 : 0x01;
  head.writeUInt32BE(counter, 33);
  if (!withCredential) return head;
  const len = Buffer.alloc(2); len.writeUInt16BE(credentialId.length);
  return Buffer.concat([head, Buffer.from("appattestdevelop"), len, credentialId]);
}

test("authenticatorData parses the rpIdHash, flags, counter and credential", () => {
  const cred = Buffer.alloc(32, 9);
  const p = parseAuthenticatorData(authData(5, true, cred));
  assert.ok(p.rpIdHash.equals(sha256(Buffer.from(appID))));
  assert.equal(p.counter, 5);
  assert.equal(p.aaguid?.toString(), "appattestdevelop");
  assert.ok(p.credentialId?.equals(cred));
  assert.throws(() => parseAuthenticatorData(Buffer.alloc(10)), /too short/);
});

test("an assertion verifies against the stored key and must advance the counter", async () => {
  useMemoryStore();
  const { privateKey, publicKey } = generateKeyPairSync("ec", { namedCurve: "P-256" });
  const keyId = sha256(uncompressedPoint(publicKey)).toString("base64");
  await saveKey(keyId, { publicKeyPem: publicKey.export({ type: "spki", format: "pem" }) as string, counter: 0, appID, environment: "production", createdAt: "", lastSeenAt: "" });

  const body = Buffer.from(JSON.stringify({ action: "expand" }));
  const clientDataHash = createHash("sha256").update(body).digest();
  const sign = (counter: number) => {
    const ad = authData(counter);
    const s = createSign("sha256"); s.update(sha256(ad, clientDataHash));
    return Buffer.from(cborEncode({ signature: s.sign(privateKey), authenticatorData: ad })).toString("base64");
  };

  const first = await verifyAssertion({ keyId, assertion: sign(1), clientDataHash, appID });
  assert.equal(first.counter, 1);
  await assert.rejects(verifyAssertion({ keyId, assertion: sign(1), clientDataHash, appID }), /counter did not advance/);
  await assert.rejects(verifyAssertion({ keyId, assertion: sign(2), clientDataHash: sha256(Buffer.from("other body")), appID }), /signature does not verify/);
  await assert.rejects(verifyAssertion({ keyId: "nope", assertion: sign(2), clientDataHash, appID }), /not attested/);

  // The same assertion opens the door through requireDevice.
  const req = { headers: { "x-forge-key-id": keyId, "x-forge-assertion": sign(3) }, body: undefined } as never;
  const device = await requireDevice(req, body);
  assert.equal(device.door, "appattest");
  assert.equal(device.id, keyId);
});

test("the nonce is read from the App Attest extension", () => {
  // A fake certificate is hard to mint; the extractor is exercised on raw DER shaped like Apple's.
  const nonce = Buffer.alloc(32, 0xab);
  const fakeRaw = Buffer.concat([Buffer.from("junk"), Buffer.from("060A2A864886F76364080202", "hex"), Buffer.from("04260424A1220420", "hex"), nonce, Buffer.from("tail")]);
  const extracted = nonceFromCertificate({ raw: fakeRaw } as never);
  assert.ok(extracted?.equals(nonce));
  assert.equal(nonceFromCertificate({ raw: Buffer.from("nothing here") } as never), null);
});

test("developer tokens open the dev door; nothing else opens any door", async () => {
  useMemoryStore();
  const ok = await requireDevice({ headers: { authorization: "Bearer dev-token-0123456789abcdef" } } as never, Buffer.from("{}"));
  assert.equal(ok.door, "dev");
  await assert.rejects(requireDevice({ headers: { authorization: "Bearer wrong-token-0123456789" } } as never, Buffer.from("{}")), (e: unknown) => e instanceof HttpError && e.status === 401);
  await assert.rejects(requireDevice({ headers: {} } as never, Buffer.from("{}")), /No device proof/);
});

test("the first check on a device is free and counts against nothing; then the allowance applies", async () => {
  useMemoryStore();
  const device = { id: "key-1", door: "appattest" as const };
  assert.deepEqual(await startCheck(device), { free: true });
  assert.deepEqual(await startCheck(device), { free: false }, "the free check is spent for good");
  assert.deepEqual(await startCheck(device), { free: false });
  await assert.rejects(startCheck(device), (e: unknown) => e instanceof HttpError && e.status === 429 && e.code === "device_limit" && /resting until tomorrow/.test(e.message));
  const usage = await usageFor(new Date().toISOString().slice(0, 10));
  assert.equal(usage.devices[0].freeChecks, 1);
  assert.equal(usage.devices[0].checks, 2, "the free one is not among the counted checks");
  // Developer tokens are neither free nor limited.
  for (let i = 0; i < 5; i++) assert.deepEqual(await startCheck({ id: "dev:1", door: "dev" }), { free: false });
});

test("per-device checks and the daily spend ceiling fail politely", async () => {
  useMemoryStore();
  const device = { id: "key-1", door: "appattest" as const };
  await startCheck(device);   // free
  await startCheck(device);
  await startCheck(device);
  await assert.rejects(startCheck(device), (e: unknown) => e instanceof HttpError && e.status === 429 && e.code === "device_limit" && /resting until tomorrow/.test(e.message));
  // Developer tokens are not limited.
  for (let i = 0; i < 5; i++) await startCheck({ id: "dev:1", door: "dev" });

  await recordUsage(device, "research", 0.6);
  await recordUsage(device, "prefill", 0.5);
  await assert.rejects(refuseIfResting(), (e: unknown) => e instanceof HttpError && e.code === "panel_resting");
  const usage = await usageFor(new Date().toISOString().slice(0, 10));
  assert.equal(usage.spendUSD, 1.1);
  assert.equal(usage.devices[0].id, "key-1");
  assert.equal(usage.devices[0].checks, 2);
  assert.equal(usage.devices[0].calls, 2);
  assert.equal(usage.devices[0].byAction.prefill, 1);
});
