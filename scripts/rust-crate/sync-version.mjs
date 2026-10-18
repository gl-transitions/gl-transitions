#!/usr/bin/env node
// Copies the crate's version, which changesets bumps in crates/gl-transitions/package.json, into
// its Cargo.toml and the Cargo.lock files (run by `pnpm run changeset:version`).
// Usage: node scripts/rust-crate/sync-version.mjs [--check]
// --check only prints the version, or fails if the files disagree.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.join(import.meta.dirname, "..", "..");
const CRATE = "crates/gl-transitions";
const MANIFEST = `${CRATE}/package.json`;
const CARGO_TOML = `${CRATE}/Cargo.toml`;
const LOCKFILES = [`${CRATE}/Cargo.lock`, "examples/fframes/Cargo.lock"];

// The `version` of the [package] table only.
const PACKAGE_VERSION = /(^\[package\]\r?\n(?:(?!\[)[^\n]*\n)*?version = ")([^"]+)(")/m;
// The path crate's lockfile entry (a registry one has a `source`).
const LOCK_ENTRY = /(^\[\[package\]\]\r?\nname = "gl-transitions"\r?\nversion = ")([^"]+)("\r?\n(?!source = ))/m;

function cargoTomlVersion(toml) {
  return toml.match(PACKAGE_VERSION)?.[2];
}

function lockVersion(lock) {
  return lock.match(LOCK_ENTRY)?.[2];
}

function replaceOnce(content, regex, version, what) {
  if (!regex.test(content)) throw new Error(`No gl-transitions version found in ${what}`);
  return content.replace(regex, `$1${version}$3`);
}

const setCargoTomlVersion = (toml, version) => replaceOnce(toml, PACKAGE_VERSION, version, CARGO_TOML);
const setLockVersion = (lock, version, file = "Cargo.lock") => replaceOnce(lock, LOCK_ENTRY, version, file);

function crateVersions(root = ROOT) {
  const read = (file) => fs.readFileSync(path.join(root, file), "utf8");
  return {
    [MANIFEST]: JSON.parse(read(MANIFEST)).version,
    [CARGO_TOML]: cargoTomlVersion(read(CARGO_TOML)),
    ...Object.fromEntries(LOCKFILES.map((file) => [file, lockVersion(read(file))])),
  };
}

function syncVersion(root = ROOT) {
  const { version } = JSON.parse(fs.readFileSync(path.join(root, MANIFEST), "utf8"));
  const update = (file, set) => {
    const before = fs.readFileSync(path.join(root, file), "utf8");
    const after = set(before, version, file);
    if (after !== before) fs.writeFileSync(path.join(root, file), after);
  };
  update(CARGO_TOML, setCargoTomlVersion);
  for (const file of LOCKFILES) update(file, setLockVersion);
  return version;
}

const isMain = process.argv[1] && fs.realpathSync(process.argv[1]) === fs.realpathSync(fileURLToPath(import.meta.url));
if (isMain && process.argv[2] === "--check") {
  const versions = crateVersions();
  if (new Set(Object.values(versions)).size !== 1) {
    console.error("The crate's versions disagree: run node scripts/rust-crate/sync-version.mjs", versions);
    process.exit(1);
  }
  console.log(versions[MANIFEST]);
} else if (isMain) console.error(`The gl-transitions crate is at version ${syncVersion()}`);

export { cargoTomlVersion, crateVersions, lockVersion, setCargoTomlVersion, setLockVersion, syncVersion };
