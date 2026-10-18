#!/usr/bin/env node
// Renders every transition with fframes (src/bin/check.rs: the gl-transitions crate's SkSL in an
// fframes shader layer, Skia on the CPU) and compares it with its GLSL reference render, as the
// other targets do (scripts/targets/compare-renders.mjs).
// Usage: node scripts/check.mjs <references dir> [--renders <dir>] [--report <file.json>]
// Fails when a transition differs from its reference (hash noise is only reported).

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { PNG } from "pngjs";
import { parseTransition } from "../../../scripts/catalog/parse-transition.mjs";
import { WIDTH, HEIGHT, fromImage, toImage, extraImage } from "../../../scripts/rendering/reference-images.mjs";
import { checkRender, usesHashNoise, writeReport } from "../../../scripts/targets/compare-renders.mjs";

const ROOT = path.join(import.meta.dirname, "..", "..", "..");
const args = process.argv.slice(2);
const refsDir = args.find((a, i) => !a.startsWith("--") && !args[i - 1]?.startsWith("--"));
const option = (name) => (args.includes(name) ? args[args.indexOf(name) + 1] : undefined);
const rendersDir = path.resolve(option("--renders") ?? fs.mkdtempSync(path.join(os.tmpdir(), "fframes-renders-")));
const reportFile = option("--report");
if (!refsDir) {
  console.error("Usage: node scripts/check.mjs <references dir> [--renders <dir>] [--report <file.json>]");
  process.exit(2);
}
if (reportFile) fs.mkdirSync(path.dirname(reportFile), { recursive: true });

// The input images of the reference renders, for the Check video.
const images = fs.mkdtempSync(path.join(os.tmpdir(), "fframes-images-"));
for (const [name, data] of Object.entries({ from: fromImage, to: toImage, extra: extraImage })) {
  const png = new PNG({ width: WIDTH, height: HEIGHT });
  png.data = Buffer.from(data);
  fs.writeFileSync(path.join(images, `${name}.png`), PNG.sync.write(png));
}
// Without H.264: the check only renders frames.
execFileSync("cargo", ["run", "--release", "--no-default-features", "--bin", "check", "--", images, rendersDir], {
  cwd: path.join(import.meta.dirname, ".."),
  stdio: "inherit",
});

const names = fs
  .readdirSync(rendersDir)
  .filter((f) => f.endsWith(".png"))
  .map((f) => f.slice(0, -".png".length))
  .sort();
const results = names.map((name) => {
  const strip = PNG.sync.read(fs.readFileSync(path.join(rendersDir, `${name}.png`))).data;
  const glsl = fs.readFileSync(path.join(ROOT, "transitions", `${name}.glsl`), "utf8");
  const hashNoise = usesHashNoise(glsl);
  // fframes' ShaderUniforms has no int2/int3/int4 values: those parameters stay 0.
  const { params } = parseTransition(glsl, `${name}.glsl`).transition;
  const ivec = Object.entries(params).filter(([, p]) => /^ivec/.test(p.type));
  if (ivec.length) {
    const error = `fframes can't set ${ivec.map(([n, p]) => `${p.type} ${n}`).join(", ")}`;
    return { name, ...(hashNoise ? { hashNoise } : {}), status: "unsupported", error };
  }
  // As in the Remotion check: fframes composites the layer over the video's background, so
  // only the pixels the reference has opaque are compared.
  const reference = path.join(refsDir, `${name}.png`);
  if (fs.existsSync(reference)) {
    const { data } = PNG.sync.read(fs.readFileSync(reference));
    if (data.length === strip.length) {
      for (let i = 3; i < data.length; i += 4) {
        if (data[i] < 255) strip.set(data.subarray(i - 3, i + 1), i - 3);
      }
    }
  }
  return { name, ...(hashNoise ? { hashNoise } : {}), ...checkRender(strip, { name, hashNoise, refsDir }) };
});

writeReport("fframes", "fframes", results, reportFile, ["match"]);
// Hash noise and the transitions fframes can't set up yet are only reported.
const differs = results.filter((r) => r.status === "differs" && !r.hashNoise).map((r) => r.name);
if (differs.length) {
  console.error(`Differ from their GLSL reference: ${differs.join(", ")}`);
  process.exit(1);
}
const missing = results.filter((r) => r.status === "no-reference").map((r) => r.name);
if (missing.length || results.length === 0) {
  console.error(`No reference render for: ${missing.join(", ") || "any transition"}`);
  process.exit(1);
}
