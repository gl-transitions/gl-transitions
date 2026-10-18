#!/usr/bin/env node
// Fills crates/gl-transitions/generated/ from the built npm package: the Rust catalog
// (catalog.rs, see crate-catalog.mjs) and the shader files it embeds with include_str!.
// The folder is not committed; `cargo package` ships it because Cargo.toml lists it in `include`,
// so the published crate is self-contained.
// Usage: node scripts/rust-crate/build-crate.mjs [--package packages/gl-transitions/dist] [--out crates/gl-transitions/generated]
// Run `pnpm run build` first.

import fs from "node:fs";
import path from "node:path";
import { TARGETS, renderCatalog } from "./crate-catalog.mjs";

const ROOT = path.join(import.meta.dirname, "..", "..");
const args = process.argv.slice(2);
let pkg = path.join(ROOT, "packages/gl-transitions/dist");
let out = path.join(ROOT, "crates/gl-transitions/generated");
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--package") pkg = path.resolve(args[++i]);
  else if (args[i] === "--out") out = path.resolve(args[++i]);
}

const read = (file) => JSON.parse(fs.readFileSync(path.join(pkg, file), "utf8"));
for (const file of ["gl-transitions.json", "layouts.json", "package.json"]) {
  if (!fs.existsSync(path.join(pkg, file))) {
    console.error(`${path.join(pkg, file)} is missing: run \`pnpm run build\` first`);
    process.exit(1);
  }
}
const transitions = read("gl-transitions.json");
const layouts = read("layouts.json");
const { version } = read("package.json");

const available = {};
for (const { name, ext } of TARGETS) {
  const d = path.join(pkg, name);
  available[name] = new Set(
    fs.existsSync(d)
      ? fs
          .readdirSync(d)
          .filter((f) => f.endsWith(ext))
          .map((f) => f.slice(0, -ext.length))
      : [],
  );
}

const { rust, files, notices } = renderCatalog({ transitions, layouts, available, version });

// Start from an empty folder so removed transitions don't linger in the crate.
fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });
for (const { from, to } of files) {
  fs.mkdirSync(path.dirname(path.join(out, to)), { recursive: true });
  fs.copyFileSync(path.join(pkg, from), path.join(out, to));
}
fs.writeFileSync(path.join(out, "catalog.rs"), rust);
fs.writeFileSync(path.join(out, "LICENSES.md"), notices);

const counts = TARGETS.map(({ name }) => `${available[name].size} ${name}`).join(", ");
console.error(
  `Wrote ${transitions.length} transitions (${counts}) of gl-transitions ${version} to ${path.relative(ROOT, out)}`,
);
