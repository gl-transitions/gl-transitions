// Run with: pnpm test
import { test } from "node:test";
import assert from "node:assert/strict";
import { renderCatalog, renderNotices, str } from "./kotlin-catalog.mjs";

const transition = (name, extra = {}) => ({
  name,
  author: "A",
  license: "MIT",
  tags: [],
  params: {},
  textures: [],
  ...extra,
});

test("kotlin catalog: sorted, only the transitions with an AGSL source", () => {
  const kotlin = renderCatalog({
    transitions: [transition("fade"), transition("Bounce", { textures: ["luma"] }), transition("noAgsl")],
    agsl: new Set(["fade", "Bounce"]),
    version: "1.2.3",
  });
  assert.match(kotlin, /internal const val CATALOG_VERSION = "1\.2\.3"/);
  assert.match(kotlin, /listOf\(\n    transition0\(\),\n    transition1\(\),\n\)/);
  assert.ok(kotlin.indexOf('"Bounce"') < kotlin.indexOf('"fade"'));
  assert.doesNotMatch(kotlin, /noAgsl/);
  assert.match(kotlin, /listOf\("luma"\),\n\)/);
});

test("kotlin catalog: typed parameter values", () => {
  const params = {
    a: { type: "float", default: 1, min: 0, max: 2 },
    b: { type: "ivec2", default: [4, 4] },
    c: { type: "vec4", default: [0, 0, 0.5, 1], color: true, description: "A $color" },
    d: { type: "bool", default: false },
  };
  const kotlin = renderCatalog({ transitions: [transition("t", { params })], agsl: new Set(["t"]), version: "1" });
  assert.match(kotlin, /Param\("a", ParamType\.FLOAT, ParamValue\.float\(1\.0f\), 0\.0f, 2\.0f, null, false, null\)/);
  assert.match(kotlin, /ParamValue\.ivec2\(4, 4\)/);
  assert.match(kotlin, /ParamValue\.vec4\(0\.0f, 0\.0f, 0\.5f, 1\.0f\), null, null, null, true, "A \\\$color"\)/);
  assert.match(kotlin, /ParamValue\.bool\(false\)/);
});

test("kotlin catalog: rejects what it can't write", () => {
  const render = (t) => () => renderCatalog({ transitions: [t], agsl: new Set([t.name]), version: "1" });
  assert.throws(render(transition("t", { params: { x: { type: "mat2", default: 0 } } })), /unsupported parameter type/);
  assert.throws(render(transition("t", { params: { x: { type: "ivec2", default: [1] } } })), /must have 2 component/);
  assert.throws(render(transition("t", { params: { x: { type: "int", default: 1.5 } } })), /not an integer/);
});

test("kotlin string literals", () => {
  assert.equal(str('a "b" \\ $c\n'), '"a \\"b\\" \\\\ \\$c\\u000a"');
});

test("license notices: the transitions that are not MIT", () => {
  const notices = renderNotices([
    transition("mit"),
    transition("bsd", { license: "BSD-3-Clause", glsl: "// (c) B\n" }),
  ]);
  assert.match(notices, /## bsd\n\nBSD-3-Clause, by A\.\n\n```glsl\n\/\/ \(c\) B\n```/);
  assert.doesNotMatch(notices, /## mit/);
});
