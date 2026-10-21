// Run with: pnpm test
import { test } from "node:test";
import assert from "node:assert/strict";
import { execFileSync, spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const SCRIPT = path.join(import.meta.dirname, "publish-mirror.mjs");

function content(dir, version, files) {
  fs.rmSync(dir, { recursive: true, force: true });
  const generated = path.join(dir, "Sources/GLTransitions/Generated");
  fs.mkdirSync(generated, { recursive: true });
  fs.writeFileSync(path.join(generated, "Catalog.swift"), `    public static let catalogVersion = "${version}"\n`);
  for (const [file, text] of Object.entries(files)) fs.writeFileSync(path.join(dir, file), text);
}

const publish = (dir, remote, version) =>
  spawnSync(process.execPath, [SCRIPT, dir, "--remote", remote, "--version", version], { encoding: "utf8" });

test("publishes each version once, as a commit on main and its tag", () => {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "publish-mirror-test-"));
  const remote = path.join(tmp, "gl-transitions-swift.git");
  const dir = path.join(tmp, "content");
  const git = (...args) => execFileSync("git", ["-C", remote, ...args], { encoding: "utf8" }).trim();
  execFileSync("git", ["init", "-q", "--bare", remote]);
  try {
    // The first release, in the empty repository.
    content(dir, "1.0.0", { "Package.swift": "a", "README.md": "1" });
    assert.equal(publish(dir, remote, "1.0.0").status, 0);
    assert.equal(git("rev-list", "--count", "main"), "1");
    assert.equal(git("rev-parse", "1.0.0^{commit}"), git("rev-parse", "main"));
    assert.equal(git("log", "-1", "--format=%s %an", "main"), "gl-transitions 1.0.0 github-actions[bot]");

    // Published already.
    assert.equal(publish(dir, remote, "1.0.0").status, 0);
    assert.equal(git("rev-list", "--count", "main"), "1");

    // The next one replaces the content.
    content(dir, "1.1.0", { "Package.swift": "b" });
    assert.equal(publish(dir, remote, "1.1.0").status, 0);
    assert.equal(git("rev-list", "--count", "main"), "2");
    assert.equal(git("rev-parse", "1.1.0^{commit}"), git("rev-parse", "main"));
    assert.equal(
      git("ls-tree", "-r", "--name-only", "main"),
      "Package.swift\nSources/GLTransitions/Generated/Catalog.swift",
    );
    assert.equal(git("show", "main:Package.swift"), "b");

    // Not the content of that version.
    assert.equal(publish(dir, remote, "1.2.0").status, 1);
    assert.equal(publish(dir, remote, "1.2.0;").status, 1);
    assert.equal(git("rev-list", "--count", "main"), "2");
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
});
