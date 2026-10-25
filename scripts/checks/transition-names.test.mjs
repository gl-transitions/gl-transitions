// Run with: pnpm test
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { nameErrors } from "./transition-names.mjs";
import { lintTransitions } from "./lint-transitions.mjs";

test("nameErrors: PascalCase names pass", () => {
  for (const name of ["Fade", "CrossZoom", "WipeLeft", "HsvFade", "ZoomInCircles", "LeafWipe"])
    assert.deepEqual(nameErrors(name), []);
});

test("nameErrors: case, acronyms and filler", () => {
  assert.match(nameErrors("fade_in")[0], /must be PascalCase/);
  assert.match(nameErrors("wipe-left")[0], /must be PascalCase/);
  assert.match(nameErrors("zoomIn")[0], /must be PascalCase/);
  assert.match(nameErrors("RGBShift")[0], /three capitals in a row/);
  assert.match(nameErrors("GlitchTransition")[0], /must not contain 'Transition'/);
});

test("nameErrors: names must differ ignoring case", () => {
  assert.match(nameErrors("CrossZOom", ["CrossZoom"])[0], /only differs from 'CrossZoom' by case/);
  assert.deepEqual(nameErrors("CrossZoom", ["CrossZoom", "Fade"]), []);
});

test("lintTransitions: reports naming errors", () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), "lint-"));
  const ok = "// Author: a\n// License: MIT\nvec4 transition(vec2 uv) { return getToColor(uv); }\n";
  fs.writeFileSync(path.join(dir, "Good.glsl"), ok);
  fs.writeFileSync(path.join(dir, "snake_case.glsl"), ok);
  fs.writeFileSync(path.join(dir, "RGBSplit.glsl"), ok);
  const { errors } = lintTransitions(dir);
  assert.equal(errors.length, 2);
  assert.ok(errors.some((e) => /snake_case\.glsl: 'snake_case' must be PascalCase/.test(e)));
  assert.ok(errors.some((e) => /RGBSplit\.glsl: 'RGBSplit' has three capitals in a row/.test(e)));
  fs.rmSync(dir, { recursive: true });
});
