#!/usr/bin/env node
// Checks that a pull request adds a changeset for each released package it changes (see
// .changeset/README.md). Transitions need none: their changesets are written at release time.
// Usage: node scripts/checks/check-changesets.mjs <base ref>

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.join(import.meta.dirname, "..", "..");
// What else ends up in each package, besides its folder in packages/ (or crates/).
const SOURCES = {
  "gl-transitions": [
    "skills/",
    "scripts/npm-package/",
    "scripts/catalog/",
    "scripts/targets/",
    "scripts/agents/",
    "scripts/rendering/",
  ],
  // Their generated types parse the transitions (scripts/catalog/generate-transition-types.mjs).
  "@gl-transitions/react-native-skia": ["scripts/catalog/"],
  "@gl-transitions/remotion": ["scripts/catalog/"],
  // The Rust crate (a private package, published to crates.io by ci.yml).
  "gl-transitions-crate": ["scripts/rust-crate/"],
};
// The folders of the released packages.
const PACKAGE_DIRS = ["packages", "crates"];

// The packages a file belongs to: tests, CHANGELOG.md and transitions/ don't count.
function packagesOf(file, packages) {
  if (/\.test\.mjs$|\/tests?\/|(^|\/)CHANGELOG\.md$/.test(file)) return [];
  return packages.filter(({ roots }) => roots.some((root) => file.startsWith(root))).map(({ name }) => name);
}

// The package names in a changeset's front matter.
function changesetPackages(content) {
  const front = content.replace(/\r\n/g, "\n").match(/^---\n([\s\S]*?)\n?---/);
  if (!front) return [];
  return [...front[1].matchAll(/^\s*["']?([^"':\s][^"':]*)["']?\s*:/gm)].map((m) => m[1].trim());
}

// `changed`: the files the pull request changes; `changesets`: the contents of the changesets it
// adds or edits. An empty changeset (no package) means no release is needed. Returns the packages that
// changed without a changeset.
function missingChangesets({ changed, changesets, packages }) {
  if (changesets.some((content) => changesetPackages(content).length === 0)) return [];
  const covered = new Set(changesets.flatMap(changesetPackages));
  const touched = new Set(changed.flatMap((file) => packagesOf(file, packages)));
  return [...touched].filter((name) => !covered.has(name)).sort();
}

// The released packages of the workspace, with the folders they are built from: the published
// ones, and the private ones that changesets versions because they have a version (the crate).
function workspacePackages(root) {
  return PACKAGE_DIRS.flatMap((parent) => {
    const dir = path.join(root, parent);
    if (!fs.existsSync(dir)) return [];
    return fs
      .readdirSync(dir)
      .map((d) => ({ d, manifest: path.join(dir, d, "package.json") }))
      .filter(({ manifest }) => fs.existsSync(manifest))
      .map(({ d, manifest }) => ({ d, pkg: JSON.parse(fs.readFileSync(manifest, "utf8")) }))
      .filter(({ pkg }) => !pkg.private || pkg.version)
      .map(({ d, pkg }) => ({
        name: pkg.name,
        roots: [`${parent}/${d}/`, ...(SOURCES[pkg.name] ?? [])],
      }));
  });
}

const isMain = process.argv[1] && fs.realpathSync(process.argv[1]) === fs.realpathSync(fileURLToPath(import.meta.url));
if (isMain) {
  const base = process.argv[2];
  if (!base) {
    console.error("Usage: node scripts/checks/check-changesets.mjs <base ref>");
    process.exit(2);
  }
  const diff = (filter) =>
    execFileSync("git", ["diff", "--name-only", "--no-renames", `--diff-filter=${filter}`, `${base}...HEAD`], {
      cwd: ROOT,
      encoding: "utf8",
    })
      .split("\n")
      .filter(Boolean);
  const changed = diff("ACDMR");
  const changesets = diff("AM")
    .filter((f) => /^\.changeset\/[^/]+\.md$/.test(f) && f !== ".changeset/README.md")
    .map((f) => fs.readFileSync(path.join(ROOT, f), "utf8"));
  const missing = missingChangesets({ changed, changesets, packages: workspacePackages(ROOT) });
  if (missing.length) {
    console.error(`No changeset for: ${missing.join(", ")}.`);
    console.error("Run `pnpm changeset` to describe the change for the changelog, or `pnpm changeset --empty`");
    console.error("if it needs no release (see .changeset/README.md).");
    process.exit(1);
  }
  console.log(changesets.length ? `${changesets.length} changesets` : "No published package changed");
}

export { changesetPackages, missingChangesets, workspacePackages };
