// The one server-side config file (config/hunch.ts), read. Models per role
// live there so they can be swapped by a proxy deploy, without an app update.
import hunch from "../config/hunch.js";

export const roles = ["research", "scoring", "brief", "plan", "tank", "fast"] as const;
export type Role = (typeof roles)[number];
export type Effort = "low" | "medium" | "high";

/// Earlier deployments set these; they still win over the file.
const legacyEnv: Partial<Record<Role, string>> = { research: "FORGE_RESEARCH_MODEL", fast: "FORGE_FAST_MODEL" };

export function modelFor(role: Role): string {
  const env = process.env[`FORGE_MODEL_${role.toUpperCase()}`] ?? (legacyEnv[role] ? process.env[legacyEnv[role]!] : undefined);
  return (env && env.trim()) || (hunch.models as Record<Role, string>)[role];
}

export function effortFor(role: Role): Effort {
  return ((hunch.effort as Partial<Record<Role, Effort>>)[role] ?? "medium");
}

export function models(): Record<Role, string> {
  return Object.fromEntries(roles.map((r) => [r, modelFor(r)])) as Record<Role, string>;
}

export const hunchConfig = hunch;
