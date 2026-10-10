#!/usr/bin/env node
// Adds the agent-facing files to the built npm package (see agent-docs.mjs):
//   <out>/llms.txt, <out>/llms-full.txt
//   <out>/skills/gl-transitions/  (copied from skills/, plus the generated references/catalog.md)
// Usage: node scripts/agents/build-agent-docs.mjs --out release
// Expects <out>/gl-transitions.json and <out>/package.json (run after the catalog build).

import fs from "node:fs";
import path from "node:path";
import { renderLlmsTxt, renderLlmsFullTxt, renderCatalogReference } from "./agent-docs.mjs";

const args = process.argv.slice(2);
let out = "release";
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--out") out = args[++i];
}

const transitions = JSON.parse(fs.readFileSync(path.join(out, "gl-transitions.json"), "utf8"));
const { version } = JSON.parse(fs.readFileSync(path.join(out, "package.json"), "utf8"));
const skslDir = path.join(out, "sksl");
const sksl = new Set(
  fs.existsSync(skslDir)
    ? fs
        .readdirSync(skslDir)
        .filter((f) => f.endsWith(".sksl"))
        .map((f) => f.slice(0, -".sksl".length))
    : [],
);

fs.writeFileSync(path.join(out, "llms.txt"), renderLlmsTxt(transitions, { version }));
fs.writeFileSync(path.join(out, "llms-full.txt"), renderLlmsFullTxt(transitions, { version, sksl }));

const skill = path.join(out, "skills", "gl-transitions");
fs.cpSync("skills/gl-transitions", skill, { recursive: true });
fs.mkdirSync(path.join(skill, "references"), { recursive: true });
fs.writeFileSync(path.join(skill, "references", "catalog.md"), renderCatalogReference(transitions, { version }));

process.stderr.write(`Wrote llms.txt, llms-full.txt and the gl-transitions skill to ${out}\n`);
