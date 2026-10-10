#!/usr/bin/env node
// Converts every transition to SkSL, compiles it with Skia (CanvasKit) and,
// when GLSL reference renders are given, renders it the same way and compares.
//
// Usage:
//   npm run build:sksl -- --out <dir> [--refs <glsl renders dir>] [--renders <dir>] [--report <file.json>]
//
//   --out      writes <name>.sksl for every transition that compiles
//   --refs     PNG strips from scripts/rendering/render-references.mjs to compare against
//   --renders  writes the SkSL renders as PNG strips, for inspection
//   --report   writes the per-transition status as JSON (also printed as a summary)
//
// Only fails on unexpected crashes: per-transition compatibility is tracked in the report.

import fs from "node:fs";
import path from "node:path";
import CanvasKitInit from "canvaskit-wasm";
import { parseTransition } from "../catalog/parse-transition.mjs";
import { WIDTH, HEIGHT, PROGRESS, fromImage, toImage, extraImage } from "../rendering/reference-images.mjs";
import { toSkSL } from "./sksl.mjs";
import { usesHashNoise, checkRender, writeReport } from "./compare-renders.mjs";

const ROOT = path.join(import.meta.dirname, "..", "..");
const args = process.argv.slice(2);
const opt = {};
for (let i = 0; i < args.length; i++) {
  if (args[i].startsWith("--")) opt[args[i].slice(2)] = path.resolve(args[++i]);
}
if (!opt.out) {
  console.error("Usage: npm run build:sksl -- --out <dir> [--refs <dir>] [--renders <dir>] [--report <file>]");
  process.exit(1);
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
  for (const file of files) {
    const { transition } = parseTransition(fs.readFileSync(path.join(dir, file), "utf8"), file);
    const result = { name: transition.name };
    if (usesHashNoise(transition.glsl)) result.hashNoise = true;
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
    result.status = "compiled";

    if (opt.refs || opt.renders) {
      const strip = render(effect, transition);
      Object.assign(
        result,
        checkRender(strip, {
          name: transition.name,
          hashNoise: result.hashNoise,
          refsDir: opt.refs,
          rendersDir: opt.renders,
        }),
      );
    }
    effect.delete();
  }

  writeReport("sksl", "SkSL", results, opt.report);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
