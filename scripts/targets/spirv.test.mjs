// Run with: npm test
import { test } from "node:test";
import assert from "node:assert/strict";
import { toVulkanGLSL, uniformLayout, tidyNames, bindMetalResources } from "./spirv.mjs";

const base = { name: "t", author: "a", license: "MIT", paramsTypes: {}, defaultParams: {}, textures: [] };

test("spirv: std140 offsets, vec3 aligned on 16 bytes, size rounded to 16", () => {
  const { uniforms, size } = uniformLayout({
    ...base,
    paramsTypes: { a: "float", center: "vec2", color: "vec3", flag: "bool", n: "ivec2" },
  });
  assert.deepEqual(
    uniforms.map((u) => [u.name, u.offset]),
    [
      ["progress", 0],
      ["ratio", 4],
      ["a", 8],
      ["center", 16],
      ["color", 32],
      ["flag", 44],
      ["n", 48],
    ],
  );
  assert.equal(size, 64);
});

test("spirv: parameters move to the uniform block, bool becomes int", () => {
  const glsl = [
    "uniform float strength; // = 0.5",
    "uniform bool flip; // = true",
    "vec4 transition(vec2 uv) { return flip ? getFromColor(uv) * strength : getToColor(uv); }",
  ].join("\n");
  const { source } = toVulkanGLSL({ ...base, glsl, paramsTypes: { strength: "float", flip: "bool" } });
  assert.match(source, /^#version 450\n/);
  assert.match(
    source,
    /uniform Uniforms \{\n {2}float progress;\n {2}float ratio;\n {2}float strength;\n {2}int flip;\n\};/,
  );
  assert.match(source, /return \(flip != 0\) \?/);
  assert.doesNotMatch(source, /uniform float strength;|uniform bool/);
});

test("spirv: extra textures get their own binding and a sampling helper", () => {
  const glsl = "uniform sampler2D luma;\nvec4 transition(vec2 uv) { return getFromColor(uv) * texture2D(luma, uv).r; }";
  const { source, layout } = toVulkanGLSL({ ...base, glsl, textures: ["luma"] });
  assert.match(source, /layout\(set = 0, binding = 4\) uniform texture2D luma;/);
  assert.match(source, /_texture_luma\(uv\)\.r/);
  assert.deepEqual(layout.textures, ["luma"]);
});

test("spirv: rejects texture() on an undeclared sampler", () => {
  const glsl = "vec4 transition(vec2 uv) { return texture2D(from, uv); }";
  assert.throws(() => toVulkanGLSL({ ...base, glsl }), /only supported on declared extra textures/);
});

test("spirv: tidyNames restores unambiguous function names and the uniform block name", () => {
  const code = [
    "fn transition_u0028_vf2_u003b(uv: vec2f) {}",
    "fn rand_u0028_f1_u003b(x: f32) {}",
    "fn rand_u0028_vf2_u003b(x: vec2f) {}",
    "let a = transition_u0028_vf2_u003b(unnamed.progress);",
  ].join("\n");
  const out = tidyNames(code);
  assert.match(out, /fn transition\(uv/);
  assert.match(out, /transition\(uniforms\.progress\)/);
  assert.match(out, /rand_u0028_f1_u003b/); // overloaded: kept
});

test("spirv: bindMetalResources assigns buffer, sampler and texture indices", () => {
  const msl = [
    ", metal::texture2d<float> _from [[user(fake0)]]",
    ", metal::sampler _sampler [[user(fake0)]]",
    ", metal::texture2d<float> _to [[user(fake0)]]",
    ", metal::texture2d<float> luma [[user(fake0)]]",
    ", constant Uniforms& uniforms [[user(fake0)]]",
  ].join("\n");
  const out = bindMetalResources(msl, { textures: ["luma"] });
  assert.match(out, /_from \[\[texture\(0\)\]\]/);
  assert.match(out, /_sampler \[\[sampler\(0\)\]\]/);
  assert.match(out, /_to \[\[texture\(1\)\]\]/);
  assert.match(out, /luma \[\[texture\(2\)\]\]/);
  assert.match(out, /uniforms \[\[buffer\(0\)\]\]/);
});
