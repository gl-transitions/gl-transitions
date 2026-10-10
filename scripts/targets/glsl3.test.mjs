// Run with: npm test
import { test } from "node:test";
import assert from "node:assert/strict";
import { toGLSL3 } from "./glsl3.mjs";

const base = { name: "t", author: "a", license: "MIT", paramsTypes: {}, defaultParams: {}, textures: [] };

test("glsl3: texture2D becomes texture, the rest is kept", () => {
  const glsl = [
    "// Author: a",
    "uniform sampler2D luma;",
    "uniform float strength; // = 0.5",
    "vec4 transition(vec2 uv) { return mix(getFromColor(uv), getToColor(uv), texture2D (luma, uv).r * strength); }",
  ].join("\n");
  const out = toGLSL3({ ...base, glsl, textures: ["luma"] });
  assert.match(out, /^\/\/ t — GLSL ES 3\.00, generated from /);
  assert.match(out, /texture \(luma, uv\)/);
  assert.doesNotMatch(out, /texture2D/);
  assert.match(out, /uniform float strength; \/\/ = 0\.5/);
});

test("glsl3: identifiers containing texture2D are left alone", () => {
  const out = toGLSL3({ ...base, glsl: "float mytexture2D(float x) { return x; }\nfloat y = mytexture2D(1.0);" });
  assert.match(out, /mytexture2D\(1\.0\)/);
});

test("glsl3: rejects a #version directive", () => {
  assert.throws(() => toGLSL3({ ...base, glsl: "#version 100\nvec4 transition(vec2 uv) { return vec4(0.0); }" }));
});
