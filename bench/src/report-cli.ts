// npm run report -- <label>: re-render a run's report from its saved files. No network.
import { render } from "./report.js";

const label = process.argv[2];
if (!label) {
  console.error("Usage: npm run report -- <label>");
  process.exit(1);
}
console.log(render(label));
