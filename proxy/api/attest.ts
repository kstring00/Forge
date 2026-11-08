import type { VercelRequest, VercelResponse } from "@vercel/node";
import { config } from "../lib/env.js";
import { HttpError, requireMethod, sendError } from "../lib/http.js";
import { parseJSONBody, readRawBody } from "../lib/auth.js";
import { AttestError, issueChallenge, saveKey, takeChallenge, verifyAttestation } from "../lib/attest.js";

export const config_ = { api: { bodyParser: false } };
export { config_ as config };

/// POST /api/attest
///   {}                                   → { challenge }       a one-time challenge, good for five minutes
///   { keyId, attestation, challenge }    → { ok: true }        the key is on record; assertions may follow
/// Open by design: attestation is how a device earns the right to call
/// anything else. Nothing here spends.
export default async function handler(req: VercelRequest, res: VercelResponse) {
  try {
    requireMethod(req, "POST");
    const body = parseJSONBody<{ keyId?: string; attestation?: string; challenge?: string }>(await readRawBody(req).then((b) => (b.length ? b : Buffer.from("{}"))));
    if (!body.keyId && !body.attestation) {
      res.status(200).json({ challenge: await issueChallenge() });
      return;
    }
    if (!body.keyId || !body.attestation || !body.challenge) {
      throw new HttpError(400, "bad_request", "keyId, attestation and challenge are required.");
    }
    if (!(await takeChallenge(body.challenge))) {
      throw new HttpError(401, "attest_bad_challenge", "That challenge was not issued, or was already used.");
    }
    try {
      const { keyId, key } = await verifyAttestation({
        keyId: body.keyId, attestation: body.attestation, challenge: body.challenge,
        appID: config.appID, allowDevelopment: config.appAttestEnvironment === "development",
      });
      await saveKey(keyId, key);
      console.log(JSON.stringify({ at: "attest", keyId: keyId.slice(0, 8) + "…", environment: key.environment }));
      res.status(200).json({ ok: true, environment: key.environment });
    } catch (err) {
      if (err instanceof AttestError) throw new HttpError(401, `attest_${err.code}`, err.message);
      throw err;
    }
  } catch (err) {
    sendError(res, err, "attest");
  }
}
