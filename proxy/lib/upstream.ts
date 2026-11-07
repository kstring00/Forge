import Anthropic from "@anthropic-ai/sdk";

/// Every non-200 from the Claude API is logged in full, so Vercel's function
/// log shows what Anthropic said, not just the status. No request body and no
/// key are logged; the error body is Anthropic's own message.
export function logUpstream(label: string, err: unknown): void {
  if (err instanceof Anthropic.APIError) {
    console.error(JSON.stringify({
      at: label,
      upstreamStatus: err.status,
      requestID: err.requestID ?? null,
      error: err.error ?? null,
      message: err.message,
    }));
  } else if (err instanceof Error) {
    console.error(JSON.stringify({ at: label, error: err.name, message: err.message }));
  } else {
    console.error(JSON.stringify({ at: label, error: String(err) }));
  }
}

/// Anthropic's own explanation, for the error body the app shows.
export function upstreamMessage(err: unknown): string | null {
  if (!(err instanceof Anthropic.APIError)) return null;
  const body = err.error as { error?: { type?: string; message?: string } } | undefined;
  const type = body?.error?.type;
  const message = body?.error?.message ?? err.message;
  return `${type ? `${type}: ` : ""}${message}`;
}
