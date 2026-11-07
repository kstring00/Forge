// Prints what the SDK sends as output_config.format for one action, with the
// counts the structured-output limits care about.
// Usage: npm run schema -- prefill [--print]
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { payloadSchemas, withRationale, type Action } from "../lib/schemas.js";

const action = (process.argv[2] ?? "prefill") as Action;
const schema: any = zodOutputFormat(withRationale(payloadSchemas[action])).schema;
let unions = 0, optional = 0, props = 0, formats = 0;
const walk = (node: any) => {
  if (!node || typeof node !== "object") return;
  if (node.format) formats++;
  if (node.properties) {
    const required = new Set<string>(node.required ?? []);
    for (const [k, v] of Object.entries<any>(node.properties)) {
      props++;
      if (!required.has(k)) optional++;
      if ((Array.isArray(v.type) && v.type.length > 1) || v.anyOf) unions++;
    }
  }
  for (const v of Object.values(node)) if (typeof v === "object") walk(v);
};
walk(schema);
console.log(`${action}: ${JSON.stringify(schema).length} bytes, ${props} properties, ${unions} union-typed (max 16), ${optional} optional (max 24), ${formats} string formats`);
if (process.argv.includes("--print")) console.log(JSON.stringify(schema, null, 2));
