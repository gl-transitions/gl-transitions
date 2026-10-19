#!/usr/bin/env node
// Writes the generated part of the Android library (android/gl-transitions) from the built npm
// package: the Kotlin catalog (src/main/kotlin/com/gltransitions/generated/Catalog.kt, see
// kotlin-catalog.mjs), and the AGSL sources and license notices it ships as Java resources
// (src/main/resources/com/gltransitions/). None of them is committed.
// Usage: node scripts/android-library/build-android-library.mjs [--package packages/gl-transitions/dist] [--out android/gl-transitions]
// Run `pnpm run build` first.

import fs from "node:fs";
import path from "node:path";
import { renderCatalog, renderNotices } from "./kotlin-catalog.mjs";

const ROOT = path.join(import.meta.dirname, "..", "..");
const args = process.argv.slice(2);
let pkg = path.join(ROOT, "packages/gl-transitions/dist");
let out = path.join(ROOT, "android/gl-transitions");
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--package") pkg = path.resolve(args[++i]);
  else if (args[i] === "--out") out = path.resolve(args[++i]);
}

for (const file of ["gl-transitions.json", "package.json", "sksl"]) {
  if (!fs.existsSync(path.join(pkg, file))) {
    console.error(`${path.join(pkg, file)} is missing: run \`pnpm run build\` first`);
    process.exit(1);
  }
}
const read = (file) => JSON.parse(fs.readFileSync(path.join(pkg, file), "utf8"));
const transitions = read("gl-transitions.json");
const { version } = read("package.json");
const agsl = new Set(
  fs
    .readdirSync(path.join(pkg, "sksl"))
    .filter((f) => f.endsWith(".sksl"))
    .map((f) => f.slice(0, -".sksl".length)),
);

const kotlin = path.join(out, "src/main/kotlin/com/gltransitions/generated");
const resources = path.join(out, "src/main/resources/com/gltransitions");
for (const dir of [kotlin, resources]) {
  fs.rmSync(dir, { recursive: true, force: true });
  fs.mkdirSync(dir, { recursive: true });
}
fs.writeFileSync(path.join(kotlin, "Catalog.kt"), renderCatalog({ transitions, agsl, version }));
fs.mkdirSync(path.join(resources, "sksl"));
for (const name of agsl)
  fs.copyFileSync(path.join(pkg, "sksl", `${name}.sksl`), path.join(resources, "sksl", `${name}.sksl`));
fs.writeFileSync(path.join(resources, "LICENSES.md"), renderNotices(transitions));

console.error(
  `Wrote ${agsl.size} of ${transitions.length} transitions of gl-transitions ${version} to ${path.relative(ROOT, out)}`,
);
