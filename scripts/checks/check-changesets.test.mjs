// Run with: pnpm test
import { test } from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { changesetPackages, missingChangesets, onlyDevDependencies, workspacePackages } from "./check-changesets.mjs";

const packages = [
  { name: "gl-transitions", roots: ["packages/gl-transitions/", "scripts/targets/"] },
  { name: "@gl-transitions/react-native-skia", roots: ["packages/react-native-skia/"] },
];
const changeset = (front) => `---\n${front}\n---\n\nSomething.\n`;

test("changesetPackages: reads the package names of the front matter", () => {
  assert.deepEqual(
    changesetPackages(changeset("\"gl-transitions\": minor\n'@gl-transitions/react-native-skia': patch")),
    ["gl-transitions", "@gl-transitions/react-native-skia"],
  );
  assert.deepEqual(changesetPackages("---\n---\n"), []);
  assert.deepEqual(changesetPackages('---\r\n"gl-transitions": minor\r\n---\r\n\r\nWindows.\r\n'), ["gl-transitions"]);
});

test("missingChangesets: a changed package needs a changeset naming it", () => {
  const changed = ["scripts/targets/build-sksl.mjs", "packages/react-native-skia/src/Transition.tsx"];
  assert.deepEqual(missingChangesets({ changed, changesets: [], packages }), [
    "@gl-transitions/react-native-skia",
    "gl-transitions",
  ]);
  assert.deepEqual(missingChangesets({ changed, changesets: [changeset('"gl-transitions": minor')], packages }), [
    "@gl-transitions/react-native-skia",
  ]);
});

test("missingChangesets: transitions, tests, changelogs and empty changesets need none", () => {
  const changed = [
    "transitions/swirl.glsl",
    "scripts/targets/sksl.test.mjs",
    "packages/react-native-skia/test/transition.test.mjs",
    "packages/gl-transitions/CHANGELOG.md",
    "README.md",
  ];
  assert.deepEqual(missingChangesets({ changed, changesets: [], packages }), []);
  const tooling = ["scripts/targets/build-sksl.mjs"];
  assert.deepEqual(missingChangesets({ changed: tooling, changesets: ["---\n---\n"], packages }), []);
});

test("workspacePackages: the published packages of this repository", () => {
  const found = workspacePackages(path.join(import.meta.dirname, "..", ".."));
  const gl = found.find((p) => p.name === "gl-transitions");
  assert.ok(gl.roots.includes("packages/gl-transitions/") && gl.roots.includes("skills/"));
  const rn = found.find((p) => p.name === "@gl-transitions/react-native-skia");
  assert.deepEqual(rn.roots, ["packages/react-native-skia/", "scripts/catalog/"]);
  const crate = found.find((p) => p.name === "gl-transitions-crate");
  assert.deepEqual(crate.roots, ["crates/gl-transitions/", "scripts/rust-crate/"]);
  assert.ok(!found.some((p) => p.name === "gl-transitions-repository" || p.name.endsWith("-example")));
});

test("missingChangesets: the crate's sources and build scripts need a changeset, its tests don't", () => {
  const crate = { name: "gl-transitions-crate", roots: ["crates/gl-transitions/", "scripts/rust-crate/"] };
  const all = [...packages, crate];
  for (const file of ["crates/gl-transitions/src/lib.rs", "scripts/rust-crate/crate-catalog.mjs"]) {
    assert.deepEqual(missingChangesets({ changed: [file], changesets: [], packages: all }), ["gl-transitions-crate"]);
  }
  const covered = [changeset('"gl-transitions-crate": patch')];
  const lib = ["crates/gl-transitions/src/lib.rs"];
  assert.deepEqual(missingChangesets({ changed: lib, changesets: covered, packages: all }), []);
  const tests = ["crates/gl-transitions/tests/sksl.rs", "scripts/rust-crate/crate-catalog.test.mjs"];
  assert.deepEqual(missingChangesets({ changed: tests, changesets: [], packages: all }), []);
});

test("onlyDevDependencies: a devDependencies bump releases nothing, anything else does", () => {
  const manifest = (fields) =>
    JSON.stringify({ name: "p", version: "1.0.0", peerDependencies: { remotion: ">=4.0.500" }, ...fields }, null, 2);
  const before = manifest({ devDependencies: { remotion: "4.0.536" } });
  assert.equal(onlyDevDependencies(before, manifest({ devDependencies: { remotion: "4.0.537" } })), true);
  assert.equal(onlyDevDependencies(before, manifest({ devDependencies: {} })), true);
  assert.equal(
    onlyDevDependencies(before, manifest({ peerDependencies: { remotion: ">=4.0.537" }, devDependencies: {} })),
    false,
  );
  assert.equal(
    onlyDevDependencies(before, manifest({ version: "1.0.1", devDependencies: { remotion: "4.0.536" } })),
    false,
  );
  assert.equal(onlyDevDependencies(before, "{ not json"), false);
});
