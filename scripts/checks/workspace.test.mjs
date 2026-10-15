// Run with: pnpm test
import { test } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";

const ROOT = path.join(import.meta.dirname, "..", "..");

// The overrides select the version, so a bump of the devDependency alone would install the
// real binaries (~750 MB) everywhere without failing anything.
test("workspace: the native-binaries stub replaces those of the package's React Native Skia", () => {
  const { devDependencies } = JSON.parse(
    fs.readFileSync(path.join(ROOT, "packages/react-native-skia/package.json"), "utf8"),
  );
  const workspace = fs.readFileSync(path.join(ROOT, "pnpm-workspace.yaml"), "utf8");
  const selected = [...workspace.matchAll(/"@shopify\/react-native-skia@([^>]+)>react-native-skia-/g)].map((m) => m[1]);
  assert.equal(selected.length, 4);
  for (const version of selected) assert.equal(version, devDependencies["@shopify/react-native-skia"]);
});
