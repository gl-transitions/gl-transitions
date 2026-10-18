// Run with: pnpm test
import { test } from "node:test";
import assert from "node:assert/strict";
import { cargoTomlVersion, crateVersions, lockVersion, setCargoTomlVersion, setLockVersion } from "./sync-version.mjs";

const toml = `[package]
name = "gl-transitions"
# A comment.
version = "0.1.0"
edition = "2021"

[dev-dependencies]
naga = { version = "30.0.1", features = ["wgsl-in"] }
`;

const lock = `[[package]]
name = "gl-transitions"
version = "9.9.9"
source = "registry+https://github.com/rust-lang/crates.io-index"

[[package]]
name = "gl-transitions"
version = "0.1.0"
dependencies = [
 "naga",
]

[[package]]
name = "gl-transitions-fframes-example"
version = "0.0.0"
`;

test("setCargoTomlVersion: changes the version of [package] only", () => {
  const next = setCargoTomlVersion(toml, "0.1.1");
  assert.equal(cargoTomlVersion(next), "0.1.1");
  assert.equal(next, toml.replace('version = "0.1.0"', 'version = "0.1.1"'));
  assert.throws(() => setCargoTomlVersion('[dependencies]\nfoo = "1"\n', "0.1.1"));
});

test("setLockVersion: changes the entry of the path crate, not a registry one", () => {
  const next = setLockVersion(lock, "0.2.0");
  assert.equal(lockVersion(next), "0.2.0");
  assert.equal(next, lock.replace('version = "0.1.0"', 'version = "0.2.0"'));
  assert.throws(() => setLockVersion('[[package]]\nname = "other"\nversion = "1.0.0"\n', "0.2.0"));
});

// changesets bumps package.json; `pnpm run changeset:version` copies the version to the others.
test("crateVersions: package.json, Cargo.toml and the Cargo.lock files agree", () => {
  const versions = crateVersions();
  const { "crates/gl-transitions/package.json": version } = versions;
  assert.match(version, /^\d+\.\d+\.\d+/);
  for (const [file, v] of Object.entries(versions)) {
    assert.equal(v, version, `${file} has ${v}: run node scripts/rust-crate/sync-version.mjs`);
  }
});
