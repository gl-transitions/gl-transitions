// Run with: node --test scripts/test
const { test } = require("node:test");
const assert = require("node:assert/strict");
const { parseHeader, parseParamAnnotations, parseTextures, parseMeta } = require("../lib/transition-meta");
const { parseTransition } = require("../lib/parse-transition");

test("header: description and tags", () => {
  const h = parseHeader("// Author: a\n// License: MIT\n// Description: A thing: with colon\n// Tags: Zoom-In, wipe, wipe\n");
  assert.equal(h.description, "A thing: with colon");
  assert.deepEqual(h.tags, ["zoom-in", "wipe"]);
  assert.deepEqual(h.errors, []);
});

test("header: absent metadata is not an error", () => {
  const h = parseHeader("// Author: a\n// License: MIT\n");
  assert.equal(h.description, undefined);
  assert.deepEqual(h.tags, []);
  assert.deepEqual(h.errors, []);
});

test("header: only the Author/License comment block counts", () => {
  const h = parseHeader("// Author: a\n// License: MIT\n\nfloat x;\n// Description : a copied noise function\n// Tags: nope\n");
  assert.equal(h.description, undefined);
  assert.deepEqual(h.tags, []);
});

test("header: invalid tag", () => {
  const h = parseHeader("// Author: a\n// Tags: ok, not ok!\n");
  assert.deepEqual(h.tags, ["ok"]);
  assert.equal(h.errors.length, 1);
});

test("annotations: range, color, description, multi-line, multi-name uniforms", () => {
  const { hints, errors } = parseParamAnnotations(
    [
      "// @range(1, 10, 1) Number of bounces",
      "uniform float bounces; // = 3.0",
      "// @color",
      "// Shadow color",
      "uniform vec4 shadow; // = vec4(0.)",
      "// @range(0, 1)",
      "uniform vec2 a /* = vec2(0.5) */, b; // = vec2(1.0)",
      "// @param Reverse direction",
      "uniform bool reversed; // = false",
      "// a regular comment",
      "uniform float plain; // = 1.0",
    ].join("\n")
  );
  assert.deepEqual(errors, []);
  assert.deepEqual(hints.bounces, { min: 1, max: 10, step: 1, description: "Number of bounces" });
  assert.deepEqual(hints.shadow, { color: true });
  assert.deepEqual(hints.a, { min: 0, max: 1 });
  assert.deepEqual(hints.b, { min: 0, max: 1 });
  assert.deepEqual(hints.reversed, { description: "Reverse direction" });
  assert.equal(hints.plain, undefined);
});

test("annotations: errors", () => {
  const { errors } = parseParamAnnotations(
    [
      "// @range(5, 1)",
      "uniform float a; // = 1.0",
      "// @range(oops)",
      "uniform float b; // = 1.0",
      "// @unknown",
      "uniform float c; // = 1.0",
      "// @color",
      "float notAUniform = 1.0;",
      "// @range(0, 1)",
    ].join("\n")
  );
  assert.equal(errors.length, 5);
  for (const malformed of ["@range(0,,1)", "@range(0,1,)", "@range(,1)"]) {
    const r = parseParamAnnotations(`// ${malformed}\nuniform float x; // = 0.5`);
    assert.match(r.errors[0], /@range expects/, malformed);
  }
  assert.match(errors[0], /min \(5\) must be lower than max/);
  assert.match(errors[1], /@range expects/);
  assert.match(errors[2], /unknown annotation '@unknown'/);
  assert.match(errors[3], /line 7: annotation must be directly above a uniform/);
  assert.match(errors[4], /line 9: annotation must be directly above a uniform/);
});

test("meta: params catalog combines types, defaults and hints", () => {
  const glsl = [
    "// @range(0, 1) Size",
    "uniform float size; // = 2.0",
    "// @color",
    "uniform float notColor; // = 1.0",
    "uniform float plain; // = 1.0",
  ].join("\n");
  const meta = parseMeta(glsl, { size: "float", notColor: "float", plain: "float" }, { size: 2, notColor: 1, plain: 1 });
  assert.deepEqual(meta.params.size, { type: "float", default: 2, min: 0, max: 1, description: "Size" });
  assert.deepEqual(meta.params.plain, { type: "float", default: 1 });
  assert.deepEqual(meta.errors, ["@color requires vec3 or vec4, 'notColor' is float"]);
  assert.deepEqual(meta.warnings, ["default of 'size' is outside its @range(0, 1)"]);
});

test("textures: extra sampler2D inputs", () => {
  assert.deepEqual(parseTextures("uniform sampler2D luma;\nuniform sampler2D a, b;"), ["luma", "a", "b"]);
});

test("parseTransition: every uniform declaration form of the spec, with hints", () => {
  const glsl = [
    "// Author: a",
    "// License: MIT",
    "// @range(0, 100)",
    "uniform float a; // = 42.0",
    "uniform float b/* = 1.0 */;",
    "// @color",
    "uniform vec3 c /* = vec3(0.9, 0.4, 0.2) */;",
    "// @range(0, 2) Both of them",
    "uniform vec2 d /*= vec2(1.0, 1.0)*/, e /* = vec2(2.) */;",
    "uniform vec2 f, g; // = vec2(1.0, 2.0); // both at once",
    "uniform float noDefault;",
    "uniform sampler2D luma;",
    "vec4 transition(vec2 uv) { return getToColor(uv); }",
  ].join("\n");
  const { transition, errors } = parseTransition(glsl, "t.glsl");
  assert.deepEqual(errors, []);
  assert.deepEqual(transition.defaultParams, {
    a: 42, b: 1, c: [0.9, 0.4, 0.2], d: [1, 1], e: [2, 2], f: [1, 2], g: [1, 2],
  });
  assert.deepEqual(transition.params.c, { type: "vec3", default: [0.9, 0.4, 0.2], color: true });
  assert.deepEqual(transition.params.e, { type: "vec2", default: [2, 2], min: 0, max: 2, description: "Both of them" });
  assert.deepEqual(transition.textures, ["luma"]);
});
