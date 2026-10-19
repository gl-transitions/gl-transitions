// Run with: pnpm test
import { test } from "node:test";
import assert from "node:assert/strict";
import { renderCatalog, renderNotices, str } from "./swift-catalog.mjs";

const transition = (name, extra = {}) => ({
  name,
  author: "A",
  license: "MIT",
  tags: [],
  params: {},
  textures: [],
  ...extra,
});
const layout = (...params) => ({
  uniforms: [
    { name: "progress", type: "float", offset: 0 },
    { name: "ratio", type: "float", offset: 4 },
    ...params.map(([name, type, offset]) => ({ name, type, offset })),
  ],
  size: 16,
  textures: [],
});

test("swift catalog: sorted, only the transitions with a Metal source", () => {
  const swift = renderCatalog({
    transitions: [transition("fade"), transition("Bounce"), transition("noMetal")],
    layouts: { fade: layout(), Bounce: layout(), noMetal: layout() },
    msl: { fade: "fragment fade", Bounce: "fragment bounce\r\n" },
    version: "1.2.3",
  });
  assert.match(swift, /public static let catalogVersion = "1\.2\.3"/);
  assert.match(swift, /public static let all: \[Transition\] = \[transition0, transition1\]/);
  assert.ok(swift.indexOf('name: "Bounce"') < swift.indexOf('name: "fade"'));
  assert.doesNotMatch(swift, /noMetal/);
  assert.match(swift, /metalSource: #"""\nfragment bounce\n"""#/);
  assert.match(swift, /UniformField\(name: "ratio", type: \.float, offset: 4\)/);
});

test("swift catalog: typed parameter values", () => {
  const params = {
    a: { type: "float", default: 0.5, min: 0, max: 1 },
    b: { type: "ivec2", default: [4, 4] },
    c: { type: "vec4", default: [0, 0, 0, 1], color: true, description: 'A "color"' },
    d: { type: "bool", default: true },
  };
  const swift = renderCatalog({
    transitions: [transition("t", { params })],
    layouts: { t: layout(["a", "float", 8], ["b", "ivec2", 16], ["c", "vec4", 32], ["d", "bool", 48]) },
    msl: { t: "" },
    version: "1.0.0",
  });
  assert.match(
    swift,
    /Param\(name: "a", type: \.float, defaultValue: \.float\(0\.5\), min: 0, max: 1, step: nil, isColor: false, description: nil\)/,
  );
  assert.match(swift, /defaultValue: \.ivec2\(SIMD2<Int32>\(4, 4\)\)/);
  assert.match(
    swift,
    /defaultValue: \.vec4\(SIMD4<Float>\(0, 0, 0, 1\)\), min: nil, max: nil, step: nil, isColor: true, description: "A \\"color\\""\)/,
  );
  assert.match(swift, /defaultValue: \.bool\(true\)/);
});

test("swift catalog: rejects what it can't write", () => {
  const render =
    (t, msl = "") =>
    () =>
      renderCatalog({ transitions: [t], layouts: { [t.name]: layout() }, msl: { [t.name]: msl }, version: "1.0.0" });
  assert.throws(
    render(transition("t", { params: { x: { type: "mat2", default: 0 } } })),
    /unsupported parameter type mat2/,
  );
  assert.throws(render(transition("t", { params: { x: { type: "ivec2", default: [1] } } })), /must have 2 components/);
  assert.throws(render(transition("t"), 'x = """#'), /"""#/);
  assert.throws(
    () => renderCatalog({ transitions: [transition("t")], layouts: {}, msl: { t: "" }, version: "1" }),
    /no uniform layout/,
  );
});

test("swift string literals", () => {
  assert.equal(str('a "b" \\ c\nd\u0001'), '"a \\"b\\" \\\\ c\\u{a}d\\u{1}"');
  assert.equal(str("Péter"), '"Péter"');
});

test("license notices: the transitions that are not MIT", () => {
  const notices = renderNotices([
    transition("mit"),
    transition("bsd", { license: "BSD-2-Clause", author: "B", glsl: "// Copyright B\nvoid main() {}\n" }),
  ]);
  assert.match(notices, /## bsd\n\nBSD-2-Clause, by B\.\n\n```glsl\n\/\/ Copyright B\nvoid main\(\) \{\}\n```/);
  assert.doesNotMatch(notices, /## mit/);
});
