// Apple App Attest, verified here so only a genuine, unmodified copy of the
// app can spend on the proxy. Two steps:
//
// 1. Attestation, once per install: the app generates a key in the Secure
//    Enclave, Apple signs a certificate for it, and the app sends the
//    attestation object with a one-time challenge from us. We check the
//    certificate chain to Apple's App Attest root, the nonce, the App ID and
//    the credential id, then keep the public key.
// 2. Assertion, on every request: the app signs SHA-256 of the request body
//    with that key. We verify the signature, the App ID and that the counter
//    moved forward.
//
// Apple's procedure: developer.apple.com/documentation/devicecheck/validating-apps-that-connect-to-your-server
import { createHash, createPublicKey, createVerify, X509Certificate, type KeyObject } from "node:crypto";
import { decode as cborDecode } from "cbor-x";
import { store } from "./store.js";

export interface AttestedKey {
  publicKeyPem: string;
  counter: number;
  appID: string;
  environment: "production" | "development";
  createdAt: string;
  lastSeenAt: string;
}

export class AttestError extends Error {
  constructor(public code: string, message: string) { super(message); }
}

const NONCE_OID_DER = Buffer.from("060A2A864886F76364080202", "hex"); // 1.2.840.113635.100.8.2, as it appears in DER
const AAGUID_DEVELOP = Buffer.from("appattestdevelop", "utf8");
const AAGUID_PRODUCTION = Buffer.concat([Buffer.from("appattest", "utf8"), Buffer.alloc(7)]);
const APPLE_ROOT_URL = "https://www.apple.com/certificateauthority/Apple_App_Attestation_Root_CA.pem";

let rootCache: X509Certificate | null = null;

/// Apple's App Attest root. From APPLE_APP_ATTEST_ROOT_PEM when set (a pin);
/// otherwise fetched once per instance from Apple over TLS.
export async function appleRoot(): Promise<X509Certificate> {
  if (rootCache) return rootCache;
  const pinned = process.env.APPLE_APP_ATTEST_ROOT_PEM;
  if (pinned && pinned.includes("BEGIN CERTIFICATE")) {
    rootCache = new X509Certificate(pinned.replace(/\\n/g, "\n"));
    return rootCache;
  }
  const res = await fetch(APPLE_ROOT_URL);
  if (!res.ok) throw new AttestError("root_unavailable", `Could not fetch Apple's App Attest root (${res.status}).`);
  const pem = await res.text();
  if (!pem.includes("BEGIN CERTIFICATE")) throw new AttestError("root_unavailable", "Apple's root did not look like a PEM certificate.");
  rootCache = new X509Certificate(pem);
  return rootCache;
}

/// Tests pin a root of their own.
export function setAppleRootForTests(cert: X509Certificate | null): void { rootCache = cert; }

export interface AuthenticatorData {
  rpIdHash: Buffer;
  flags: number;
  counter: number;
  aaguid?: Buffer;
  credentialId?: Buffer;
}

/// authenticatorData: rpIdHash (32) · flags (1) · counter (4, big-endian) ·
/// then, when the attested-credential flag is set, aaguid (16) · credIdLen (2) · credId.
export function parseAuthenticatorData(data: Buffer): AuthenticatorData {
  if (data.length < 37) throw new AttestError("bad_auth_data", "authenticatorData is too short.");
  const out: AuthenticatorData = { rpIdHash: data.subarray(0, 32), flags: data[32], counter: data.readUInt32BE(33) };
  if (out.flags & 0x40) {
    if (data.length < 55) throw new AttestError("bad_auth_data", "authenticatorData has no credential.");
    out.aaguid = data.subarray(37, 53);
    const len = data.readUInt16BE(53);
    out.credentialId = data.subarray(55, 55 + len);
  }
  return out;
}

export function sha256(...parts: Buffer[]): Buffer {
  const h = createHash("sha256");
  for (const p of parts) h.update(p);
  return h.digest();
}

/// The nonce Apple put in the credential certificate: the last OCTET STRING in
/// the extension with the App Attest OID. The extension's DER is
/// SEQUENCE { [1] { OCTET STRING nonce } }.
export function nonceFromCertificate(cert: X509Certificate): Buffer | null {
  const raw = cert.raw;
  const at = raw.indexOf(NONCE_OID_DER);
  if (at < 0) return null;
  // After the OID: OCTET STRING (extnValue) wrapping SEQUENCE { A1 { 04 20 <nonce> } }.
  const window = raw.subarray(at + NONCE_OID_DER.length, at + NONCE_OID_DER.length + 96);
  const marker = window.indexOf(Buffer.from([0x04, 0x20]));
  if (marker < 0) return null;
  return window.subarray(marker + 2, marker + 34);
}

/// The uncompressed EC point (0x04 || X || Y) of a P-256 public key.
export function uncompressedPoint(key: KeyObject): Buffer {
  const jwk = key.export({ format: "jwk" }) as { x?: string; y?: string };
  if (!jwk.x || !jwk.y) throw new AttestError("bad_key", "The credential key is not an EC key.");
  return Buffer.concat([Buffer.from([0x04]), Buffer.from(jwk.x, "base64url"), Buffer.from(jwk.y, "base64url")]);
}

export interface AttestationInput {
  keyId: string;           // base64, as the app sends it
  attestation: string;     // base64 CBOR
  challenge: string;       // the one-time challenge we issued, as the app echoes it
  appID: string;           // "TEAMID.bundle.id"
  allowDevelopment: boolean;
}

/// Verifies an attestation object and returns the key to keep.
export async function verifyAttestation(input: AttestationInput): Promise<{ keyId: string; key: AttestedKey }> {
  let obj: { fmt?: string; attStmt?: { x5c?: Uint8Array[]; receipt?: Uint8Array }; authData?: Uint8Array };
  try {
    obj = cborDecode(Buffer.from(input.attestation, "base64"));
  } catch {
    throw new AttestError("bad_attestation", "The attestation is not CBOR.");
  }
  if (obj.fmt !== "apple-appattest" || !obj.attStmt?.x5c?.length || !obj.authData) {
    throw new AttestError("bad_attestation", "The attestation is not an Apple App Attest object.");
  }
  const chain = obj.attStmt.x5c.map((der) => new X509Certificate(Buffer.from(der)));
  const credCert = chain[0];
  const root = await appleRoot();

  // 1. The chain ends at Apple's root.
  let issuer = root;
  for (let i = chain.length - 1; i >= 0; i--) {
    const cert = chain[i];
    if (!cert.checkIssued(issuer) || !cert.verify(issuer.publicKey)) {
      throw new AttestError("bad_chain", "The attestation certificate chain does not lead to Apple's App Attest root.");
    }
    const now = Date.now();
    if (new Date(cert.validFrom).getTime() > now || new Date(cert.validTo).getTime() < now) {
      throw new AttestError("bad_chain", "A certificate in the attestation chain is not currently valid.");
    }
    issuer = cert;
  }

  // 2–4. nonce = SHA256(authData || SHA256(challenge)) must match the certificate's.
  const authData = Buffer.from(obj.authData);
  const clientDataHash = sha256(Buffer.from(input.challenge, "utf8"));
  const expectedNonce = sha256(authData, clientDataHash);
  const certNonce = nonceFromCertificate(credCert);
  if (!certNonce || !certNonce.equals(expectedNonce)) {
    throw new AttestError("bad_nonce", "The attestation nonce does not match our challenge.");
  }

  // 5. The key id is the hash of the credential's public key.
  const point = uncompressedPoint(credCert.publicKey);
  const keyIdBytes = Buffer.from(input.keyId, "base64");
  if (!sha256(point).equals(keyIdBytes)) {
    throw new AttestError("bad_key_id", "The key id is not the hash of the attested key.");
  }

  // 6–9. App ID, counter, environment, credential id.
  const parsed = parseAuthenticatorData(authData);
  if (!parsed.rpIdHash.equals(sha256(Buffer.from(input.appID, "utf8")))) {
    throw new AttestError("bad_app_id", "The attestation is for a different app.");
  }
  if (parsed.counter !== 0) throw new AttestError("bad_counter", "A fresh attestation must have counter 0.");
  let environment: AttestedKey["environment"];
  if (parsed.aaguid?.equals(AAGUID_PRODUCTION)) environment = "production";
  else if (parsed.aaguid?.equals(AAGUID_DEVELOP)) environment = "development";
  else throw new AttestError("bad_environment", "Unknown App Attest environment.");
  if (environment === "development" && !input.allowDevelopment) {
    throw new AttestError("bad_environment", "Development attestations are not accepted by this proxy.");
  }
  if (!parsed.credentialId || !parsed.credentialId.equals(keyIdBytes)) {
    throw new AttestError("bad_key_id", "The credential id does not match the key id.");
  }

  const now = new Date().toISOString();
  return {
    keyId: input.keyId,
    key: { publicKeyPem: credCert.publicKey.export({ type: "spki", format: "pem" }) as string, counter: 0, appID: input.appID, environment, createdAt: now, lastSeenAt: now },
  };
}

export interface AssertionInput {
  keyId: string;
  assertion: string;       // base64 CBOR { signature, authenticatorData }
  clientDataHash: Buffer;  // SHA256 of the exact request body bytes
  appID: string;
}

/// Verifies an assertion against a stored key and advances its counter.
export async function verifyAssertion(input: AssertionInput): Promise<AttestedKey> {
  const s = store();
  const key = await s.get<AttestedKey>(`attest:key:${input.keyId}`);
  if (!key) throw new AttestError("unknown_key", "This device has not attested, or its key is no longer on record.");
  let obj: { signature?: Uint8Array; authenticatorData?: Uint8Array };
  try {
    obj = cborDecode(Buffer.from(input.assertion, "base64"));
  } catch {
    throw new AttestError("bad_assertion", "The assertion is not CBOR.");
  }
  if (!obj.signature || !obj.authenticatorData) throw new AttestError("bad_assertion", "The assertion is missing fields.");
  const authData = Buffer.from(obj.authenticatorData);
  const nonce = sha256(authData, input.clientDataHash);
  const verifier = createVerify("sha256");
  verifier.update(nonce);
  const ok = verifier.verify(createPublicKey(key.publicKeyPem), Buffer.from(obj.signature));
  if (!ok) throw new AttestError("bad_signature", "The assertion signature does not verify.");
  const parsed = parseAuthenticatorData(authData);
  if (!parsed.rpIdHash.equals(sha256(Buffer.from(input.appID, "utf8")))) throw new AttestError("bad_app_id", "The assertion is for a different app.");
  if (parsed.counter <= key.counter) throw new AttestError("replay", "The assertion counter did not advance.");
  const updated: AttestedKey = { ...key, counter: parsed.counter, lastSeenAt: new Date().toISOString() };
  await s.set(`attest:key:${input.keyId}`, updated);
  return updated;
}

/// A one-time challenge for an attestation, good for five minutes.
export async function issueChallenge(): Promise<string> {
  const challenge = Buffer.from(crypto.getRandomValues(new Uint8Array(32))).toString("base64url");
  await store().set(`attest:challenge:${challenge}`, 1, 300);
  return challenge;
}

/// Consumes a challenge; false if it was never issued or already used.
export async function takeChallenge(challenge: string): Promise<boolean> {
  return store().take(`attest:challenge:${challenge}`);
}

export async function saveKey(keyId: string, key: AttestedKey): Promise<void> {
  await store().set(`attest:key:${keyId}`, key);
}
