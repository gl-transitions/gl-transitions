#!/usr/bin/env node
// Publishes the content written by build-mirror.mjs to the gl-transitions-swift repository: one
// commit on main replacing its content, tagged with the version (SwiftPM resolves plain semver
// tags). Does nothing when the tag exists; never force-pushes. CI runs it with a deploy key
// (GIT_SSH_COMMAND), and against a local repository in the pull requests.
// Usage: node scripts/swift-package/publish-mirror.mjs <content> --remote <git url> --version <version>

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";

const args = process.argv.slice(2);
let content;
let remote;
let version;
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--remote") remote = args[++i];
  else if (args[i] === "--version") version = args[++i];
  else content = path.resolve(args[i]);
}
if (!content || !remote || !version) {
  console.error(
    "Usage: node scripts/swift-package/publish-mirror.mjs <content> --remote <git url> --version <version>",
  );
  process.exit(2);
}
if (!/^\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$/.test(version)) {
  console.error(`${version} is not a version`);
  process.exit(1);
}
if (fs.existsSync(path.join(content, ".git"))) {
  console.error(`${content} has a .git`);
  process.exit(1);
}
const catalog = fs.readFileSync(path.join(content, "Sources/GLTransitions/Generated/Catalog.swift"), "utf8");
if (!catalog.includes(`public static let catalogVersion = "${version}"\n`)) {
  console.error(`${content} is not the content of ${version}`);
  process.exit(1);
}

const work = fs.mkdtempSync(path.join(os.tmpdir(), "gl-transitions-swift-"));
const git = (...args) =>
  execFileSync(
    "git",
    [
      "-c",
      "user.name=github-actions[bot]",
      "-c",
      "user.email=41898282+github-actions[bot]@users.noreply.github.com",
      "-c",
      "commit.gpgsign=false",
      "-c",
      "tag.gpgsign=false",
      ...args,
    ],
    { cwd: work, encoding: "utf8", stdio: ["ignore", "pipe", "inherit"] },
  );
// git ls-remote --exit-code: 2 when nothing matches.
function exists(ref) {
  try {
    git("ls-remote", "--exit-code", "origin", ref);
    return true;
  } catch (error) {
    if (error.status === 2) return false;
    throw error;
  }
}

try {
  git("init", "-q", "-b", "main");
  git("remote", "add", "origin", remote);
  if (exists(`refs/tags/${version}`)) {
    console.error(`${version} is already published`);
  } else {
    // The first release starts the history.
    if (exists("refs/heads/main")) {
      git("fetch", "-q", "--depth=1", "origin", "main");
      git("reset", "-q", "FETCH_HEAD");
    }
    fs.cpSync(content, work, { recursive: true });
    git("add", "--all");
    git("commit", "-q", "-m", `gl-transitions ${version}`);
    git("tag", "-a", version, "-m", `gl-transitions ${version}`);
    git("push", "-q", "--atomic", "origin", "refs/heads/main", `refs/tags/${version}`);
    console.error(`Published ${version}`);
  }
} finally {
  fs.rmSync(work, { recursive: true, force: true });
}
