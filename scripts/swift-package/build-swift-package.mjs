#!/usr/bin/env node
// Writes the generated part of the Swift package (swift/) from the built npm package: the catalog
// with the Metal sources (Sources/GLTransitions/Generated/Catalog.swift, see swift-catalog.mjs) and
// the license notices of the transitions that are not MIT (LICENSES.md). Neither is committed.
// Usage: node scripts/swift-package/build-swift-package.mjs [--package packages/gl-transitions/dist] [--out swift]
// Run `pnpm run build` first.

import fs from "node:fs";
import path from "node:path";
import { renderCatalog, renderNotices } from "./swift-catalog.mjs";

const ROOT = path.join(import.meta.dirname, "..", "..");
const args = process.argv.slice(2);
let pkg = path.join(ROOT, "packages/gl-transitions/dist");
let out = path.join(ROOT, "swift");
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--package") pkg = path.resolve(args[++i]);
  else if (args[i] === "--out") out = path.resolve(args[++i]);
}

for (const file of ["gl-transitions.json", "layouts.json", "package.json", "msl"]) {
  if (!fs.existsSync(path.join(pkg, file))) {
    console.error(`${path.join(pkg, file)} is missing: run \`pnpm run build\` first`);
    process.exit(1);
  }
}
const read = (file) => JSON.parse(fs.readFileSync(path.join(pkg, file), "utf8"));
const transitions = read("gl-transitions.json");
const layouts = read("layouts.json");
const { version } = read("package.json");
const msl = {};
for (const file of fs.readdirSync(path.join(pkg, "msl"))) {
  if (file.endsWith(".metal"))
    msl[file.slice(0, -".metal".length)] = fs.readFileSync(path.join(pkg, "msl", file), "utf8");
}

const generated = path.join(out, "Sources/GLTransitions/Generated");
fs.rmSync(generated, { recursive: true, force: true });
fs.mkdirSync(generated, { recursive: true });
fs.writeFileSync(path.join(generated, "Catalog.swift"), renderCatalog({ transitions, layouts, msl, version }));
fs.writeFileSync(path.join(out, "LICENSES.md"), renderNotices(transitions));

console.error(
  `Wrote ${Object.keys(msl).length} of ${transitions.length} transitions of gl-transitions ${version} to ${path.relative(ROOT, generated)}`,
);
