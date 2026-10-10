#!/usr/bin/env node
// Converts every transition to GLSL ES 3.00 and validates it with glslang, the
// Khronos reference compiler, inside the reference wrapper (GLSL3_WRAPPER).
//
// Usage:
//   npm run build:glsl3 -- --out <dir> [--report <file.json>]
//
//   --out      writes <name>.glsl for every transition that compiles
//   --report   writes the per-transition status as JSON (also printed as a summary)
//
// Compiled only, not rendered: headless GL is WebGL 1 only.
// Only fails on unexpected crashes: per-transition compatibility is tracked in the report.

import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { parseTransition } from "../catalog/parse-transition.mjs";
import { toGLSL3, GLSL3_WRAPPER } from "./glsl3.mjs";
import { glslangValidator } from "./toolchain.mjs";

const ROOT = path.join(import.meta.dirname, "..", "..");

const args = process.argv.slice(2);
const opt = {};
for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith("--")) opt[args[i].slice(2)] = path.resolve(args[++i]);
}
if (!opt.out) {
  console.error("Usage: npm run build:glsl3 -- --out <dir> [--report <file>]");
  process.exit(1);
}

const glslang = await glslangValidator();
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "glsl3-"));

// Returns glslang's error messages, or "" when the shader compiles.
function validate(name, source) {
  const file = path.join(tmp, `${name}.frag`);
  fs.writeFileSync(file, GLSL3_WRAPPER.before + source + GLSL3_WRAPPER.after);
  const { status, stdout, stderr, error } = spawnSync(glslang, [file], { encoding: "utf8" });
  if (error) throw error;
  if (status === 0) return "";
  return (
    (stdout + stderr)
      .split("\n")
      .filter((l) => /ERROR|error/.test(l) && !/compilation errors/.test(l))
      .map((l) => l.replace(`${file}:`, "").trim())
      .join("\n") || `glslang exited with ${status}`
  );
}

const dir = path.join(ROOT, "transitions");
const files = fs
  .readdirSync(dir)
  .filter((f) => f.endsWith(".glsl") && fs.statSync(path.join(dir, f)).isFile())
  .sort();
fs.mkdirSync(opt.out, { recursive: true });

const results = [];
for (const file of files) {
  const { transition } = parseTransition(fs.readFileSync(path.join(dir, file), "utf8"), file);
  const result = { name: transition.name };
  results.push(result);
  let source;
  try {
    source = toGLSL3(transition);
  } catch (e) {
    Object.assign(result, { status: "unsupported", error: e.message });
    continue;
  }
  const error = validate(transition.name, source);
  if (error) {
    Object.assign(result, { status: "compile-error", error });
    continue;
  }
  fs.writeFileSync(path.join(opt.out, `${transition.name}.glsl`), source);
  result.status = "compiled";
}
fs.rmSync(tmp, { recursive: true, force: true });

const counts = {};
for (const r of results) counts[r.status] = (counts[r.status] || 0) + 1;
const report = { target: "glsl3", total: results.length, counts, transitions: results };
if (opt.report) fs.writeFileSync(opt.report, JSON.stringify(report, null, 2) + "\n");

console.log(
  `GLSL ES 3.00: ${Object.entries(counts)
    .map(([k, v]) => `${v} ${k}`)
    .join(", ")} (of ${results.length})`,
);
for (const r of results) {
  if (r.status !== "compiled") console.log(`  ${r.status.padEnd(13)} ${r.name}: ${r.error.split("\n")[0]}`);
}
