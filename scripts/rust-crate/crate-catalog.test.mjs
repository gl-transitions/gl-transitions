// Run with: pnpm test
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { parseTransition } from "../catalog/parse-transition.mjs";
import { renderCatalog } from "./crate-catalog.mjs";

const transition = (name, extra = {}) => ({
  name,
  author: "A",
  license: "MIT",
  tags: [],
  params: {},
  textures: [],
  ...extra,
});
const layout = { uniforms: [{ name: "progress", type: "float", offset: 0 }], size: 16, textures: [] };

test("rust catalog: sorted, with the files of each target that exists", () => {
  const { rust, files } = renderCatalog({
    transitions: [transition("fade"), transition("Bounce")],
    layouts: { fade: layout },
    available: { sksl: new Set(["fade", "Bounce"]), wgsl: new Set(["fade"]) },
    version: "1.2.3",
  });
  assert.match(rust, /pub const CATALOG_VERSION: &str = "1\.2\.3";/);
  assert.ok(rust.indexOf('name: "Bounce"') < rust.indexOf('name: "fade"'), "byte order: uppercase first");
  assert.match(rust, /#\[allow\(clippy::approx_constant/);
  assert.match(rust, /#\[cfg\(feature = "wgsl"\)\]\n\s+wgsl: Some\(include_str!\("wgsl\/fade.wgsl"\)\)/);
  assert.match(rust, /#\[cfg\(feature = "wgsl"\)\]\n\s+wgsl: None,/);
  assert.match(rust, /#\[cfg\(feature = "msl"\)\]\n\s+msl: None,/);
  assert.match(rust, /uniform_layout: None,/);
  assert.match(rust, /UniformField \{ name: "progress", ty: ParamType::Float, offset: 0 \}/);
  assert.deepEqual(
    files.map((f) => f.to).sort(),
    ["glsl/Bounce.glsl", "glsl/fade.glsl", "sksl/Bounce.sksl", "sksl/fade.sksl", "wgsl/fade.wgsl"].sort(),
  );
  assert.deepEqual(
    files.find((f) => f.to === "glsl/fade.glsl"),
    { from: "transitions/fade.glsl", to: "glsl/fade.glsl" },
  );
});

test("rust catalog: typed defaults and Rust string escapes", () => {
  const { rust } = renderCatalog({
    transitions: [
      transition("t", {
        author: 'Jane "J" Doe\\',
        description: "Line\nbreak, ünïcode",
        params: {
          a: { type: "float", default: 3, min: 0, max: 1e-7 },
          b: { type: "ivec2", default: [4, -4] },
          c: { type: "bool", default: true, color: false },
          d: { type: "vec4", default: [0, 0.5, 1, 1], color: true, description: "Tint" },
        },
      }),
    ],
    layouts: {},
    available: {},
    version: "1.0.0",
  });
  assert.match(rust, /author: "Jane \\"J\\" Doe\\\\",/);
  assert.match(rust, /description: Some\("Line\\nbreak, ünïcode"\),/);
  assert.match(rust, /default: Value::Float\(3\.0\),\n\s+min: Some\(0\.0\),\n\s+max: Some\(1e-7\),/);
  assert.match(rust, /default: Value::IVec2\(\[4, -4\]\)/);
  assert.match(rust, /default: Value::Bool\(true\)/);
  assert.match(
    rust,
    /default: Value::Vec4\(\[0\.0, 0\.5, 1\.0, 1\.0\]\),[^]*?color: true,\n\s+description: Some\("Tint"\)/,
  );
});

test("rust catalog: refuses defaults that don't match their type", () => {
  const render = (p) =>
    renderCatalog({ transitions: [transition("t", { params: { p } })], layouts: {}, available: {}, version: "1" });
  assert.throws(() => render({ type: "vec2", default: [1] }), /t\.p: vec2 default must have 2 components/);
  assert.throws(() => render({ type: "int", default: 1.5 }), /not an integer/);
  assert.throws(() => render({ type: "int", default: 2 ** 31 }), /out of the i32 range/);
  assert.throws(() => render({ type: "bool", default: 1 }), /bool default must be a boolean/);
  assert.throws(() => render({ type: "mat2", default: [1, 0, 0, 1] }), /unsupported parameter type mat2/);
});

// A new parameter type or a malformed default fails here, before the crate fails to compile.
test("rust catalog: every transition of the repository renders", () => {
  const dir = path.join(import.meta.dirname, "..", "..", "transitions");
  const transitions = fs
    .readdirSync(dir)
    .filter((f) => f.endsWith(".glsl"))
    .map((f) => ({
      name: f.slice(0, -".glsl".length),
      ...parseTransition(fs.readFileSync(path.join(dir, f), "utf8"), f).transition,
    }));
  const { rust } = renderCatalog({ transitions, layouts: {}, available: {}, version: "1.0.0" });
  assert.equal(rust.match(/^ {4}Transition \{$/gm).length, transitions.length);
  const params = transitions.reduce((n, t) => n + Object.keys(t.params).length, 0);
  assert.ok(params > 100, `${params} parameters`);
  assert.equal(rust.match(/^ {12}Param \{$/gm).length, params);
});

test("rust catalog: the license notices hold the source of every non-MIT transition", () => {
  const { notices } = renderCatalog({
    transitions: [
      transition("a"),
      transition("b", { license: "BSD 2 Clause", glsl: "// Copyright (c) B\nvec4 transition(vec2 uv);\n" }),
    ],
    layouts: {},
    available: {},
    version: "1.0.0",
  });
  assert.match(
    notices,
    /## b\n\nBSD 2 Clause, by A\.\n\n```glsl\n\/\/ Copyright \(c\) B\nvec4 transition\(vec2 uv\);\n```/,
  );
  assert.doesNotMatch(notices, /## a/);
});
