#!/usr/bin/env node
// Merges the targets' reports (build-sksl, build-glsl3, build-wgsl-msl --report) into
// the compatibility matrix shipped in the npm package, and a Markdown summary for CI.
//
// Usage:
//   npm run build:compatibility -- [--out <compatibility.json>] [--summary <file.md>] <report.json> ...

import fs from "node:fs";

// `rendered` (set from the reports) says whether the statuses come from a comparison with
// the GLSL reference renders (SkSL and WGSL, when the build is given them) or only a compiler.
const TARGETS = {
  sksl: { language: "SkSL", path: "sksl/{name}.sksl" },
  glsl3: { language: "GLSL ES 3.00", path: "glsl3/{name}.glsl" },
  wgsl: { language: "WGSL", path: "wgsl/{name}.wgsl" },
  msl: { language: "Metal Shading Language", path: "msl/{name}.metal" },
};
// Statuses for which the file is shipped and expected to work.
const OK = ["match", "noise-only", "close", "compiled", "translated"];
const STATUS_ORDER = [
  "match",
  "noise-only",
  "close",
  "compiled",
  "translated",
  "differs",
  "no-reference",
  "compile-error",
  "unsupported",
];

const args = process.argv.slice(2);
const opt = {};
const reportFiles = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--out" || args[i] === "--summary") opt[args[i].slice(2)] = args[++i];
  else reportFiles.push(args[i]);
}
if (!reportFiles.length) {
  console.error("Usage: npm run build:compatibility -- [--out <file>] [--summary <file.md>] <report.json> ...");
  process.exit(1);
}

// A report is { target, transitions } or, for build-wgsl-msl, { wgsl: {...}, msl: {...} }.
const reports = reportFiles
  .map((f) => JSON.parse(fs.readFileSync(f, "utf8")))
  .flatMap((r) => (r.target ? [r] : Object.values(r)));

const targets = {};
const transitions = {};
for (const report of reports) {
  if (!TARGETS[report.target]) throw new Error(`unknown target '${report.target}'`);
  const rendered = report.transitions.some((t) => t.differingPixels !== undefined);
  targets[report.target] = { ...TARGETS[report.target], rendered };
  for (const { name, status, error, differingPixels, hashNoise } of report.transitions) {
    const entry = { status };
    if (differingPixels !== undefined) entry.differingPixels = differingPixels;
    if (hashNoise) entry.hashNoise = true;
    if (error) entry.error = error.split("\n")[0];
    (transitions[name] ||= {})[report.target] = entry;
  }
}
const sorted = Object.fromEntries(
  Object.keys(transitions)
    .sort()
    .map((n) => [n, transitions[n]]),
);
const matrix = { targets, transitions: sorted };
if (opt.out) fs.writeFileSync(opt.out, JSON.stringify(matrix, null, 2) + "\n");

// --- Markdown summary ---

const names = Object.keys(targets);
const lines = ["## Compatibility", "", `| Status | ${names.map((t) => targets[t].language).join(" | ")} |`];
lines.push(`|---|${names.map(() => "---:").join("|")}|`);
for (const status of STATUS_ORDER) {
  const counts = names.map((t) => Object.values(sorted).filter((e) => e[t]?.status === status).length);
  if (counts.some(Boolean)) lines.push(`| ${status} | ${counts.map((c) => c || "").join(" | ")} |`);
}
const flagged = Object.entries(sorted).filter(([, e]) => names.some((t) => e[t] && !OK.includes(e[t].status)));
if (flagged.length) {
  lines.push("", "<details><summary>Transitions with a target that does not work</summary>", "");
  lines.push(`| Transition | ${names.join(" | ")} |`, `|---|${names.map(() => "---").join("|")}|`);
  for (const [name, e] of flagged) {
    const cell = (t) => {
      if (!e[t]) return "";
      const { status, differingPixels, hashNoise, error } = e[t];
      const notes = [
        differingPixels !== undefined && !OK.includes(status) ? `${(differingPixels * 100).toFixed(1)}%` : "",
        hashNoise && !OK.includes(status) ? "hash noise" : "",
        error ? error.slice(0, 120).replace(/[\\|]/g, "\\$&") : "",
      ].filter(Boolean);
      return notes.length ? `${status} (${notes.join(", ")})` : status;
    };
    lines.push(`| \`${name}\` | ${names.map(cell).join(" | ")} |`);
  }
  lines.push("", "</details>");
}
const summary = lines.join("\n") + "\n";
if (opt.summary) fs.writeFileSync(opt.summary, summary);
else console.log(summary);
