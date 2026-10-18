#!/usr/bin/env node
// Renders the Check composition (src/Check.tsx) with Remotion's renderer and compares every
// transition with its GLSL reference render, as the other targets do (compare-renders.mjs).
// Usage: node scripts/check.mjs <references dir> [--renders <dir>] [--report <file.json>]
// Fails when a transition differs from its reference (hash noise is only reported).

import fs from "node:fs";
import path from "node:path";
import { bundle } from "@remotion/bundler";
import { renderFrames, selectComposition } from "@remotion/renderer";
import { PNG } from "pngjs";
import transitions from "gl-transitions";
import { WIDTH, HEIGHT, PROGRESS } from "../../../scripts/rendering/reference-images.mjs";
import { checkRender, usesHashNoise, writeReport } from "../../../scripts/targets/compare-renders.mjs";

const args = process.argv.slice(2);
const refsDir = args.find((a, i) => !a.startsWith("--") && !args[i - 1]?.startsWith("--"));
const option = (name) => (args.includes(name) ? args[args.indexOf(name) + 1] : undefined);
const rendersDir = option("--renders");
const reportFile = option("--report");
if (!refsDir) {
  console.error("Usage: node scripts/check.mjs <references dir> [--renders <dir>] [--report <file.json>]");
  process.exit(2);
}
if (rendersDir) fs.mkdirSync(rendersDir, { recursive: true });
if (reportFile) fs.mkdirSync(path.dirname(reportFile), { recursive: true });

const serveUrl = await bundle({ entryPoint: path.join(import.meta.dirname, "..", "src", "index.ts") });
const composition = await selectComposition({ serveUrl, id: "Check", inputProps: {} });
if (composition.width !== WIDTH || composition.height !== HEIGHT) {
  throw new Error(
    `The Check composition is ${composition.width}x${composition.height}, the references ${WIDTH}x${HEIGHT}`,
  );
}
// Each transition lasts the same number of frames (src/Check.tsx): transition k shows progress p
// at frame TRANSITION * (k + p).
const TRANSITION = composition.durationInFrames / transitions.length;
const frameOf = (k, p) => Math.round(TRANSITION * (k + p));
const frames = transitions.flatMap((_, k) => PROGRESS.map((p) => frameOf(k, p)));
const captured = new Map();
await renderFrames({
  composition,
  serveUrl,
  inputProps: {},
  imageFormat: "png",
  outputDir: null,
  frames,
  onFrameBuffer: (buffer, frame) => {
    captured.set(frame, PNG.sync.read(buffer).data);
  },
  // WebGL in headless Chrome without a GPU (as on CI runners), see Remotion's docs.
  chromiumOptions: { gl: process.env.REMOTION_GL ?? "swangle" },
  onStart: () => console.log(`Rendering ${frames.length} frames of ${transitions.length} transitions…`),
});

const stripWidth = WIDTH * PROGRESS.length;
const results = transitions.map((transition, k) => {
  const strip = new Uint8Array(stripWidth * HEIGHT * 4);
  PROGRESS.forEach((p, f) => {
    const data = captured.get(frameOf(k, p));
    for (let y = 0; y < HEIGHT; y++) {
      strip.set(data.subarray(y * WIDTH * 4, (y + 1) * WIDTH * 4), (y * stripWidth + f * WIDTH) * 4);
    }
  });
  const { name } = transition;
  const hashNoise = usesHashNoise(transition.glsl);
  // Saves the render as is.
  if (rendersDir) checkRender(strip, { name, rendersDir });
  // Where the reference is transparent (LeftRight, Bounce's shadow…), Remotion's output shows a
  // captured scene or black, not transparency: only its opaque pixels are compared.
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

writeReport("remotion", "Remotion", results, reportFile, ["match"]);
const differs = results.filter((r) => r.status === "differs" && !r.hashNoise).map((r) => r.name);
if (differs.length) {
  console.error(`Differ from their GLSL reference: ${differs.join(", ")}`);
  process.exit(1);
}
// Nothing compared is not a pass (a missing or empty references folder).
const missing = results.filter((r) => r.status === "no-reference").map((r) => r.name);
if (missing.length) {
  console.error(`No reference render for: ${missing.join(", ")}`);
  process.exit(1);
}
