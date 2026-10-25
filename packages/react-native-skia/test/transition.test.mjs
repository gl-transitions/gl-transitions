// Renders every transition through the built package (dist/) with React Native Skia's
// headless build, using gl-transitions built from this repository.
//
// With GL_TRANSITIONS_REFS=<dir> (PNG strips from scripts/rendering/render-references.mjs),
// also compares every render against the GLSL reference.

import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { registerHooks } from "node:module";
import { pathToFileURL } from "node:url";
import { createElement } from "react";
import {
  WIDTH,
  HEIGHT,
  PROGRESS,
  fromImage,
  toImage,
  extraImage,
} from "../../../scripts/rendering/reference-images.mjs";
import { checkRender, usesHashNoise } from "../../../scripts/targets/compare-renders.mjs";

const ROOT = path.join(import.meta.dirname, "..", "..", "..");
const REFS = process.env.GL_TRANSITIONS_REFS;
// A pixel differs when a channel moves by more than PIXEL_TOLERANCE (out of 255).
const PIXEL_TOLERANCE = 16;

// gl-transitions as build.sh packages it: the catalog and the SkSL index.
const pkg = fs.mkdtempSync(path.join(os.tmpdir(), "gl-transitions-"));
after(() => fs.rmSync(pkg, { recursive: true, force: true }));
execFileSync("node", ["scripts/catalog/build-catalog.mjs", "-d", "transitions", "-o", path.join(pkg, "catalog.json")], {
  cwd: ROOT,
});
fs.writeFileSync(path.join(pkg, "index.js"), `module.exports=${fs.readFileSync(path.join(pkg, "catalog.json"))}`);
execFileSync("node", ["scripts/targets/build-sksl.mjs", "--out", path.join(pkg, "sksl")], { cwd: ROOT });

// ESM entry points that require() them: CommonJS imported through a resolve hook loses module.exports.
function esmWrapper(file) {
  const wrapper = `${file}.wrapper.mjs`;
  const source = `import { createRequire } from "node:module";\nexport default createRequire(import.meta.url)(${JSON.stringify(file)});\n`;
  fs.writeFileSync(wrapper, source);
  return wrapper;
}
const aliases = {
  "gl-transitions": esmWrapper(path.join(pkg, "index.js")),
  "gl-transitions/sksl/index.js": esmWrapper(path.join(pkg, "sksl", "index.js")),
  "@shopify/react-native-skia": path.join(import.meta.dirname, "skia-headless.mjs"),
};
registerHooks({
  resolve(specifier, context, nextResolve) {
    if (aliases[specifier]) return { url: pathToFileURL(aliases[specifier]).href, shortCircuit: true };
    return nextResolve(specifier, context);
  },
});

const catalog = JSON.parse(fs.readFileSync(path.join(pkg, "catalog.json"), "utf8"));
const { Transition, getTransitionEffect, makeUniforms } = await import("../dist/index.js");
const { AlphaType, ColorType, Skia, drawOffscreen, makeOffscreenSurface } = await import("./skia-headless.mjs");

const info = { width: WIDTH, height: HEIGHT, colorType: ColorType.RGBA_8888, alphaType: AlphaType.Unpremul };
const image = (rgba) => Skia.Image.MakeImage(info, Skia.Data.fromBytes(rgba), WIDTH * 4);
let from, to, extra, surface;
before(() => {
  from = image(fromImage);
  to = image(toImage);
  extra = image(extraImage);
  surface = makeOffscreenSurface(WIDTH, HEIGHT);
});

async function render(name, progress, params) {
  const transition = catalog.find((t) => t.name === name);
  const textures = Object.fromEntries(transition.textures.map((t) => [t, extra]));
  surface.getCanvas().clear(Skia.Color("transparent"));
  const props = { name, from, to, progress, params, textures, width: WIDTH, height: HEIGHT, fit: "fill" };
  const snapshot = await drawOffscreen(surface, createElement(Transition, props));
  return snapshot.readPixels(0, 0, info);
}

// Ratio of pixels where a channel differs by more than PIXEL_TOLERANCE.
function differing(actual, expected) {
  let bad = 0;
  for (let i = 0; i < actual.length; i += 4) {
    if (actual[i + 3] === 0 && expected[i + 3] === 0) continue;
    for (let c = 0; c < 4; c++) {
      if (Math.abs(actual[i + c] - expected[i + c]) > PIXEL_TOLERANCE) {
        bad++;
        break;
      }
    }
  }
  return bad / (actual.length / 4);
}

test("every transition compiles and gets exactly the uniforms its effect declares", () => {
  for (const transition of catalog) {
    const { effect } = getTransitionEffect(transition.name);
    const uniforms = makeUniforms(transition, WIDTH, HEIGHT, 0.5);
    const declared = {};
    for (let i = 0; i < effect.getUniformCount(); i++) {
      const { columns, rows } = effect.getUniform(i);
      declared[effect.getUniformName(i)] = columns * rows;
    }
    const given = Object.fromEntries(Object.entries(uniforms).map(([k, v]) => [k, [].concat(v).length]));
    assert.deepEqual(given, declared, transition.name);
  }
});

test("every transition draws", async () => {
  for (const { name } of catalog) {
    const pixels = await render(name, 0.5);
    assert.ok(
      pixels.some((v, i) => i % 4 === 3 && v > 0),
      name,
    );
  }
});

// Fade and LumaWipe have an exact expected output: they check the orientation, the order of
// the children (from, to, then textures) and the uniforms.
test("draws `from`, `to` and the textures upright and in order", async () => {
  const mixed = fromImage.map((v, i) => Math.round((v + toImage[i]) / 2));
  assert.equal(differing(await render("Fade", 0), fromImage), 0);
  assert.equal(differing(await render("Fade", 1), toImage), 0);
  assert.equal(differing(await render("Fade", 0.5), mixed), 0);
  // LumaWipe: `from` where the luma texture is brighter than progress, `to` elsewhere.
  const luma = fromImage.map((v, i) => (extraImage[i - (i % 4)] / 255 >= 0.4 ? v : toImage[i]));
  assert.ok(differing(await render("LumaWipe", 0.4), luma) <= 0.001);
});

test("params override the defaults, bool params included", async () => {
  const melt = (direction) => render("LuminanceMelt", 0.5, { direction });
  assert.ok(differing(await melt(true), await melt(false)) > 0.05);
  assert.deepEqual(await render("Cube", 0.5, { persp: 0.7 }), await render("Cube", 0.5));
  assert.ok(differing(await render("Cube", 0.5, { persp: 0.1 }), await render("Cube", 0.5)) > 0.05);
});

test("unknown transitions throw", () => {
  assert.throws(() => getTransitionEffect("nope"), /unknown transition 'nope'/);
});

// Compared like build-sksl.mjs compares the SkSL renders. Hash noise (fract(sin(x) * 43758.5453))
// differs between implementations, even by blocks here: it is reported, not checked.
test("matches the GLSL reference renders", { skip: !REFS && "set GL_TRANSITIONS_REFS to compare" }, async () => {
  const stripWidth = WIDTH * PROGRESS.length;
  const results = [];
  for (const { name, glsl } of catalog) {
    const strip = new Uint8Array(stripWidth * HEIGHT * 4);
    for (const [f, progress] of PROGRESS.entries()) {
      const frame = await render(name, progress);
      for (let y = 0; y < HEIGHT; y++) {
        strip.set(frame.subarray(y * WIDTH * 4, (y + 1) * WIDTH * 4), (y * stripWidth + f * WIDTH) * 4);
      }
    }
    const hashNoise = usesHashNoise(glsl);
    results.push({ name, hashNoise, ...checkRender(strip, { name, hashNoise, refsDir: REFS }) });
  }
  const off = results.filter((r) => r.status !== "match");
  console.log(`${results.length - off.length} of ${results.length} transitions match their GLSL reference`);
  for (const r of off)
    console.log(`  ${r.status} ${r.name}${r.hashNoise ? " [hash noise]" : ""}${r.error ? `: ${r.error}` : ""}`);
  assert.deepEqual(
    results.filter((r) => r.status === "differs" && !r.hashNoise).map((r) => r.name),
    [],
    "transitions that differ from their GLSL reference",
  );
});
