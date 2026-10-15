// Run with: pnpm test
import { test } from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { changesetPackages, missingChangesets, workspacePackages } from "./check-changesets.mjs";

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
});
