#!/usr/bin/env node
// Compares software measures of the collection with GPU ones, to choose the renderer of the PR
// preview and the limits of frame-cost.mjs.
// Usage: node scripts/checks/calibrate-cost.mjs <gpu.json> <software.json>...
// with reports of `pnpm run bench --json`; several software ones are averaged (geometric mean).

import fs from "node:fs";
import { LIMITS, WARNING_MS, bestLimit, detection, spearman } from "./frame-cost.mjs";

const [gpuFile, ...softwareFiles] = process.argv.slice(2);
if (!softwareFiles.length) {
  console.error("Usage: node scripts/checks/calibrate-cost.mjs <gpu.json> <software.json>...");
  process.exit(1);
}
const readReport = (file) => {
  const { fade, transitions } = JSON.parse(fs.readFileSync(file, "utf8"));
  return { fade, costs: new Map(transitions.filter((t) => !t.error).map((t) => [t.name, t])) };
};
const gpu = readReport(gpuFile);
const software = softwareFiles.map(readReport);
const names = [...gpu.costs.keys()].filter((name) => software.every(({ costs }) => costs.has(name)));
const truth = names.map((name) => gpu.costs.get(name).worst);
const relatives = software.map(({ costs }) => names.map((name) => costs.get(name).relative));
const estimate = names.map((_, i) =>
  Math.exp(relatives.reduce((sum, relative) => sum + Math.log(relative[i]), 0) / relatives.length),
);

console.log(`${names.length} transitions, Fade ${gpu.fade.toFixed(3)} ms on the GPU`);
relatives.forEach((relative, i) =>
  console.log(`Spearman of ${softwareFiles[i]}: ${spearman(relative, truth).toFixed(3)}`),
);
const describe = ({ limit, found, missed, wrong }) =>
  `x${limit.toFixed(1)} finds ${found}, misses ${missed}, warns wrongly about ${wrong}`;
for (const [level, ms] of Object.entries(WARNING_MS)) {
  const current = LIMITS.software[level];
  const list = (test) =>
    names
      .map((name, i) => ({ name, truth: truth[i], estimate: estimate[i] }))
      .filter(test)
      .sort((a, b) => b.truth - a.truth)
      .map((t) => `${t.name} (${t.truth.toFixed(1)} ms, x${t.estimate.toFixed(1)})`)
      .join(", ") || "none";
  console.log(`\n${level}: ${ms} ms, x${(ms / gpu.fade).toFixed(1)} Fade on the GPU`);
  console.log(`  best software limit: ${describe(bestLimit(estimate, truth, ms))}`);
  console.log(`  current one: ${describe(detection(estimate, truth, current, ms))}`);
  console.log(`  missed: ${list((t) => t.truth >= ms && t.estimate < current)}`);
  console.log(`  wrong: ${list((t) => t.truth < ms && t.estimate >= current)}`);
}
