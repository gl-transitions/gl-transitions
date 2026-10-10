#!/usr/bin/env node
// Converts every transition to SkSL, compiles it with Skia (CanvasKit) and,
// when GLSL reference renders are given, renders it the same way and compares.
//
// Usage:
//   npm run build:sksl -- --out <dir> [--refs <glsl renders dir>] [--renders <dir>] [--report <file.json>]
//
//   --out      writes <name>.sksl for every transition that compiles, and index.js mapping
//              each name to its source (for bundlers that can't import .sksl files)
//   --refs     PNG strips from scripts/rendering/render-references.mjs to compare against
//   --renders  writes the SkSL renders as PNG strips, for inspection
//   --report   writes the per-transition status as JSON (also printed as a summary)
//
// Only fails on unexpected crashes: per-transition compatibility is tracked in the report.

import fs from "node:fs";
import path from "node:path";
import CanvasKitInit from "canvaskit-wasm";
import { PNG } from "pngjs";
import { parseTransition } from "../catalog/parse-transition.mjs";
import { WIDTH, HEIGHT, PROGRESS, fromImage, toImage, extraImage } from "../rendering/reference-images.mjs";
import { toSkSL } from "./sksl.mjs";

const ROOT = path.join(import.meta.dirname, "..", "..");
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

const args = process.argv.slice(2);
const opt = {};
for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith("--")) opt[args[i].slice(2)] = path.resolve(args[++i]);
}
if (!opt.out) {
  console.error("Usage: npm run build:sksl -- --out <dir> [--refs <dir>] [--renders <dir>] [--report <file>]");
  process.exit(1);
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

async function main() {
  const CanvasKit = await CanvasKitInit();

  function imageShader(rgba) {
    const image = CanvasKit.MakeImage(
      {
        width: WIDTH,
        height: HEIGHT,
        colorType: CanvasKit.ColorType.RGBA_8888,
        alphaType: CanvasKit.AlphaType.Unpremul,
        colorSpace: CanvasKit.ColorSpace.SRGB,
      },
      rgba,
      WIDTH * 4,
    );
    return image.makeShaderOptions(
      CanvasKit.TileMode.Clamp,
      CanvasKit.TileMode.Clamp,
      CanvasKit.FilterMode.Linear,
      CanvasKit.MipmapMode.None,
    );
  }
  const fromShader = imageShader(fromImage);
  const toShader = imageShader(toImage);
  const extraShader = imageShader(extraImage);
  const surface = CanvasKit.MakeSurface(WIDTH, HEIGHT);

  function render(effect, transition) {
    const values = {
      _resolution: [WIDTH, HEIGHT],
      ratio: [WIDTH / HEIGHT],
      progress: [0],
    };
    for (const [name, value] of Object.entries(transition.defaultParams)) {
      values[name] = [].concat(value).map(Number);
    }
    const uniforms = new Float32Array(effect.getUniformFloatCount());
    const progressSlots = [];
    for (let i = 0; i < effect.getUniformCount(); i++) {
      const name = effect.getUniformName(i);
      const { slot } = effect.getUniform(i);
      if (name === "progress") progressSlots.push(slot);
      (values[name] || []).forEach((v, k) => (uniforms[slot + k] = v));
    }
    const children = [fromShader, toShader, ...transition.textures.map(() => extraShader)];
    const strip = Buffer.alloc(WIDTH * PROGRESS.length * HEIGHT * 4);
    const canvas = surface.getCanvas();
    PROGRESS.forEach((p, f) => {
      progressSlots.forEach((s) => (uniforms[s] = p));
      const shader = effect.makeShaderWithChildren(uniforms, children);
      const paint = new CanvasKit.Paint();
      paint.setShader(shader);
      canvas.clear(CanvasKit.TRANSPARENT);
      canvas.drawPaint(paint);
      const pixels = canvas.readPixels(0, 0, {
        width: WIDTH,
        height: HEIGHT,
        colorType: CanvasKit.ColorType.RGBA_8888,
        alphaType: CanvasKit.AlphaType.Unpremul,
        colorSpace: CanvasKit.ColorSpace.SRGB,
      });
      for (let y = 0; y < HEIGHT; y++) {
        strip.set(pixels.subarray(y * WIDTH * 4, (y + 1) * WIDTH * 4), (y * WIDTH * PROGRESS.length + f * WIDTH) * 4);
      }
      paint.delete();
      shader.delete();
    });
    return strip;
  }

  const dir = path.join(ROOT, "transitions");
  const files = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".glsl") && fs.statSync(path.join(dir, f)).isFile())
    .sort();
  fs.mkdirSync(opt.out, { recursive: true });
  if (opt.renders) fs.mkdirSync(opt.renders, { recursive: true });

  const results = [];
  const sources = {};
  for (const file of files) {
    const { transition } = parseTransition(fs.readFileSync(path.join(dir, file), "utf8"), file);
    const result = { name: transition.name };
    // Hash noise (fract(sin(x) * 43758.5453)) amplifies tiny sin() differences between
    // implementations, so these transitions can't be expected to match pixel for pixel.
    if (/fract\s*\(\s*sin\s*\(/.test(transition.glsl)) result.hashNoise = true;
    results.push(result);

    let source;
    try {
      source = toSkSL(transition);
    } catch (e) {
      Object.assign(result, { status: "unsupported", error: e.message });
      continue;
    }
    let compileError = "";
    const effect = CanvasKit.RuntimeEffect.Make(source, (err) => (compileError += err));
    if (!effect) {
      Object.assign(result, { status: "compile-error", error: compileError.trim() });
      continue;
    }
    fs.writeFileSync(path.join(opt.out, `${transition.name}.sksl`), source);
    sources[transition.name] = source;
    result.status = "compiled";

    if (opt.refs || opt.renders) {
      const strip = render(effect, transition);
      if (opt.renders) {
        const png = new PNG({ width: WIDTH * PROGRESS.length, height: HEIGHT });
        png.data = strip;
        fs.writeFileSync(path.join(opt.renders, `${transition.name}.png`), PNG.sync.write(png));
      }
      const ref = opt.refs && path.join(opt.refs, `${transition.name}.png`);
      const reference = ref && fs.existsSync(ref) ? PNG.sync.read(fs.readFileSync(ref)) : null;
      if (ref && !reference) {
        Object.assign(result, { status: "no-reference", error: `missing ${ref}` });
      } else if (reference && (reference.width !== WIDTH * PROGRESS.length || reference.height !== HEIGHT)) {
        Object.assign(result, {
          status: "no-reference",
          error: `${ref} is ${reference.width}x${reference.height}, expected ${WIDTH * PROGRESS.length}x${HEIGHT}`,
        });
      } else if (reference) {
        const expected = reference.data;
        const { status, worst } = compare(strip, expected);
        Object.assign(result, { status, differingPixels: Math.round(worst * 1000) / 1000 });
        if (status !== "match" && result.hashNoise && compareBlocks(strip, expected) <= CLOSE_RATIO) {
          result.status = "noise-only";
        }
      }
    }
    effect.delete();
  }

  fs.writeFileSync(path.join(opt.out, "index.js"), `module.exports=${JSON.stringify(sources)};\n`);

  const counts = {};
  for (const r of results) counts[r.status] = (counts[r.status] || 0) + 1;
  const report = { target: "sksl", total: results.length, counts, transitions: results };
  if (opt.report) fs.writeFileSync(opt.report, JSON.stringify(report, null, 2) + "\n");

  console.log(
    `SkSL: ${Object.entries(counts)
      .map(([k, v]) => `${v} ${k}`)
      .join(", ")} (of ${results.length})`,
  );
  for (const r of results) {
    if (!["match", "compiled"].includes(r.status)) {
      console.log(
        `  ${r.status.padEnd(13)} ${r.name}${r.hashNoise ? " [hash noise]" : ""}${r.differingPixels !== undefined ? ` (${(r.differingPixels * 100).toFixed(1)}% of pixels differ)` : ""}${r.error ? `: ${r.error.split("\n")[0]}` : ""}`,
      );
    }
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
