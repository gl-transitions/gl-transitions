// Run with: npm test
import { test } from "node:test";
import assert from "node:assert/strict";
import { preprocess } from "./glsl-preprocess.mjs";
import { toSkSL } from "./sksl.mjs";

test("preprocess: object-like, function-like and nested macros", () => {
  const out = preprocess(
    [
      "#define PI 3.14 // comment",
      "#define SQ(x) ((x)*(x))",
      "#define TWO_PI (2.0*PI)",
      "float a = SQ(PI) + TWO_PI + SQ(f(1.0, 2.0));",
      "float PIE = obj.PI;",
    ].join("\n"),
  );
  assert.match(
    out,
    /float a = \(\(3\.14\)\*\(3\.14\)\) \+ \(2\.0\*3\.14\) \+ \(\(f\(1\.0, 2\.0\)\)\*\(f\(1\.0, 2\.0\)\)\);/,
  );
  assert.match(out, /float PIE = obj\.PI;/);
});

test("preprocess: GL_ES blocks are dropped, #else is kept", () => {
  const out = preprocess("#ifdef GL_ES\nprecision highp float;\n#else\nfloat x;\n#endif\n");
  assert.doesNotMatch(out, /precision/);
  assert.match(out, /float x;/);
});

test("preprocess: keeps line numbers", () => {
  const out = preprocess("/* a\nb */\n#define X 1\nfloat y = X;");
  assert.equal(out.split("\n")[3], "float y = 1;");
});

test("preprocess: rejects unsupported directives", () => {
  assert.throws(() => preprocess("#version 300 es\n"), /unsupported directive #version/);
});

const base = { name: "t", author: "a", license: "MIT", paramsTypes: {}, defaultParams: {}, textures: [] };

test("sksl: wraps transition with children, uniforms and main", () => {
  const src = toSkSL({
    ...base,
    glsl: "vec4 transition(vec2 uv) { return mix(getFromColor(uv), getToColor(uv), progress); }",
  });
  assert.match(src, /uniform shader _from;/);
  assert.match(src, /uniform float2 _resolution;/);
  assert.match(src, /half4 main\(float2 _coord\)/);
});

test("sksl: bool uniforms become int", () => {
  const src = toSkSL({
    ...base,
    paramsTypes: { reversed: "bool" },
    glsl: "uniform bool reversed; // = false\nvec4 transition(vec2 uv) { float x = reversed ? 1.0 - uv.x : uv.x; return getFromColor(vec2(x, uv.y)); }",
  });
  assert.match(src, /uniform int reversed;/);
  assert.match(src, /float x = \(reversed != 0\) \? 1\.0 - uv\.x : uv\.x;/);
});

test("sksl: extra textures become child shaders", () => {
  const src = toSkSL({
    ...base,
    textures: ["luma"],
    glsl: "uniform sampler2D luma;\nvec4 transition(vec2 uv) { return mix(getToColor(uv), getFromColor(uv), step(progress, texture2D(luma, uv).r)); }",
  });
  assert.match(src, /uniform shader luma;\nvec4 _texture_luma\(vec2 uv\)/);
  assert.match(src, /step\(progress, _texture_luma\( uv\)\.r\)/);
});
