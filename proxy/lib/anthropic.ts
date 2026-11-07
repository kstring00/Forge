import Anthropic from "@anthropic-ai/sdk";
import { config } from "./env.js";

let client: Anthropic | null = null;

export function anthropic(): Anthropic {
  if (!client) {
    client = new Anthropic({
      apiKey: config.anthropicApiKey,
      maxRetries: 2,
      timeout: 55_000, // under Vercel's 60s function cap
    });
  }
  return client;
}
