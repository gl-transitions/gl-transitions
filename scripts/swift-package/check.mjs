#!/usr/bin/env node
// Renders every transition with the Swift package (swift/Sources/gl-transitions-check: the Metal
// shaders drawn by TransitionRenderer) and compares it with its GLSL reference render, as the other
// targets do (scripts/targets/compare-renders.mjs). macOS only.
// Usage: node scripts/swift-package/check.mjs <references dir> [--renders <dir>] [--report <file.json>]
// Fails when a transition differs from its reference (hash noise is only reported) or does not compile.

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { PNG } from "pngjs";
import { WIDTH, HEIGHT, PROGRESS, fromImage, toImage, extraImage } from "../rendering/reference-images.mjs";
import { checkRender, usesHashNoise, writeReport } from "../targets/compare-renders.mjs";

const ROOT = path.join(import.meta.dirname, "..", "..");
const args = process.argv.slice(2);
const refsDir = args.find((a, i) => !a.startsWith("--") && !args[i - 1]?.startsWith("--"));
const option = (name) => (args.includes(name) ? args[args.indexOf(name) + 1] : undefined);
const rendersDir = path.resolve(option("--renders") ?? fs.mkdtempSync(path.join(os.tmpdir(), "swift-renders-")));
const reportFile = option("--report");
if (!refsDir) {
  console.error(
    "Usage: node scripts/swift-package/check.mjs <references dir> [--renders <dir>] [--report <file.json>]",
  );
  process.exit(2);
}
if (reportFile) fs.mkdirSync(path.dirname(reportFile), { recursive: true });

const images = fs.mkdtempSync(path.join(os.tmpdir(), "swift-images-"));
for (const [name, data] of Object.entries({ from: fromImage, to: toImage, extra: extraImage })) {
  const png = new PNG({ width: WIDTH, height: HEIGHT });
  png.data = Buffer.from(data);
  fs.writeFileSync(path.join(images, `${name}.png`), PNG.sync.write(png));
}
fs.rmSync(rendersDir, { recursive: true, force: true });
execFileSync("swift", ["run", "-c", "release", "gl-transitions-check", images, rendersDir, PROGRESS.join(",")], {
  cwd: path.join(ROOT, "swift"),
  stdio: "inherit",
});

const names = fs
  .readdirSync(rendersDir)
  .filter((f) => /\.(png|error)$/.test(f))
  .map((f) => f.replace(/\.(png|error)$/, ""))
  .sort();
const results = names.map((name) => {
  const hashNoise = usesHashNoise(fs.readFileSync(path.join(ROOT, "transitions", `${name}.glsl`), "utf8"));
  const noise = hashNoise ? { hashNoise } : {};
  const error = path.join(rendersDir, `${name}.error`);
  if (fs.existsSync(error)) return { name, ...noise, status: "compile-error", error: fs.readFileSync(error, "utf8") };
  const png = PNG.sync.read(fs.readFileSync(path.join(rendersDir, `${name}.png`)));
  if (png.width !== WIDTH * PROGRESS.length || png.height !== HEIGHT) {
    return { name, ...noise, status: "differs", error: `rendered ${png.width}x${png.height}` };
  }
  return { name, ...noise, ...checkRender(png.data, { name, hashNoise, refsDir }) };
});

writeReport("swift", "Swift (Metal)", results, reportFile, ["match"]);
const differs = results
  .filter((r) => (r.status === "differs" && (!r.hashNoise || r.error)) || r.status === "compile-error")
  .map((r) => r.name);
if (differs.length) {
  console.error(`Differ from their GLSL reference or don't compile: ${differs.join(", ")}`);
  process.exit(1);
}
const missing = results.filter((r) => r.status === "no-reference").map((r) => r.name);
if (missing.length || results.length === 0) {
  console.error(`No reference render for: ${missing.join(", ") || "any transition"}`);
  process.exit(1);
}
