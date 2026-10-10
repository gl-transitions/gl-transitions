// Compares a target's render of a transition with the GLSL reference render, and
// the shared parts of the targets' reports. Used by every target that can render.

import fs from "node:fs";
import path from "node:path";
import { PNG } from "pngjs";
import { WIDTH, HEIGHT, PROGRESS } from "../rendering/reference-images.mjs";

// A pixel "differs" when a channel moves by more than PIXEL_TOLERANCE (out of 255).
// Different GPUs and CPUs legitimately disagree on hash noise (fract(sin(x) * 43758.5453)),
// so a frame "matches" when at most MATCH_RATIO of its pixels differ, and is "close"
// up to CLOSE_RATIO.
const PIXEL_TOLERANCE = 16;
const MATCH_RATIO = 0.01;
const CLOSE_RATIO = 0.05;
// For hash-noise transitions, compare BLOCK x BLOCK averages instead: same structure,
// different noise grain is reported as "noise-only".
const BLOCK = 10;
const BLOCK_TOLERANCE = 24;

// Hash noise amplifies tiny sin() differences between implementations, so these
// transitions can't be expected to match pixel for pixel.
function usesHashNoise(glsl) {
  return /fract\s*\(\s*sin\s*\(/.test(glsl);
}

function compare(actual, expected) {
  const stripWidth = WIDTH * PROGRESS.length;
  const bad = new Array(PROGRESS.length).fill(0);
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < stripWidth; x++) {
      const i = (y * stripWidth + x) * 4;
      if (actual[i + 3] === 0 && expected[i + 3] === 0) continue; // fully transparent: color is meaningless
      for (let c = 0; c < 4; c++) {
        if (Math.abs(actual[i + c] - expected[i + c]) > PIXEL_TOLERANCE) {
          bad[Math.floor(x / WIDTH)]++;
          break;
        }
      }
    }
  }
  const worst = Math.max(...bad) / (WIDTH * HEIGHT);
  return { worst, status: worst <= MATCH_RATIO ? "match" : worst <= CLOSE_RATIO ? "close" : "differs" };
}

// Ratio of BLOCK x BLOCK blocks whose average color differs, worst frame.
function compareBlocks(actual, expected) {
  const stripWidth = WIDTH * PROGRESS.length;
  let worst = 0;
  PROGRESS.forEach((_, f) => {
    let bad = 0;
    let total = 0;
    for (let by = 0; by < HEIGHT; by += BLOCK) {
      for (let bx = f * WIDTH; bx < (f + 1) * WIDTH; bx += BLOCK) {
        const sum = [0, 0, 0, 0, 0, 0, 0, 0];
        for (let y = by; y < by + BLOCK; y++) {
          for (let x = bx; x < bx + BLOCK; x++) {
            const i = (y * stripWidth + x) * 4;
            for (let c = 0; c < 4; c++) {
              sum[c] += actual[i + c];
              sum[4 + c] += expected[i + c];
            }
          }
        }
        total++;
        const n = BLOCK * BLOCK;
        if ([0, 1, 2, 3].some((c) => Math.abs(sum[c] - sum[4 + c]) / n > BLOCK_TOLERANCE)) bad++;
      }
    }
    worst = Math.max(worst, bad / total);
  });
  return worst;
}

// Writes the strip to `rendersDir` if given, compares it with `refsDir`/<name>.png if given,
// and returns the fields to merge into the transition's report entry.
function checkRender(strip, { name, hashNoise, refsDir, rendersDir }) {
  if (rendersDir) {
    const png = new PNG({ width: WIDTH * PROGRESS.length, height: HEIGHT });
    png.data = Buffer.from(strip);
    fs.writeFileSync(path.join(rendersDir, `${name}.png`), PNG.sync.write(png));
  }
  if (!refsDir) return {};
  const ref = path.join(refsDir, `${name}.png`);
  if (!fs.existsSync(ref)) return { status: "no-reference", error: `missing ${ref}` };
  const reference = PNG.sync.read(fs.readFileSync(ref));
  if (reference.width !== WIDTH * PROGRESS.length || reference.height !== HEIGHT) {
    return {
      status: "no-reference",
      error: `${ref} is ${reference.width}x${reference.height}, expected ${WIDTH * PROGRESS.length}x${HEIGHT}`,
    };
  }
  const { status, worst } = compare(strip, reference.data);
  const result = { status, differingPixels: Math.round(worst * 1000) / 1000 };
  if (status !== "match" && hashNoise && compareBlocks(strip, reference.data) <= CLOSE_RATIO) {
    result.status = "noise-only";
  }
  return result;
}

// Writes the report and prints a summary listing the transitions that need attention.
function writeReport(target, label, results, reportFile, ok = ["match", "compiled"]) {
  const counts = {};
  for (const r of results) counts[r.status] = (counts[r.status] || 0) + 1;
  const report = { target, total: results.length, counts, transitions: results };
  if (reportFile) fs.writeFileSync(reportFile, JSON.stringify(report, null, 2) + "\n");
  console.log(
    `${label}: ${Object.entries(counts)
      .map(([k, v]) => `${v} ${k}`)
      .join(", ")} (of ${results.length})`,
  );
  for (const r of results) {
    if (!ok.includes(r.status)) {
      console.log(
        `  ${r.status.padEnd(13)} ${r.name}${r.hashNoise ? " [hash noise]" : ""}${r.differingPixels !== undefined ? ` (${(r.differingPixels * 100).toFixed(1)}% of pixels differ)` : ""}${r.error ? `: ${r.error.split("\n")[0]}` : ""}`,
      );
    }
  }
  return report;
}

export { usesHashNoise, checkRender, writeReport };
