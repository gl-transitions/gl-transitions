#!/usr/bin/env node
// Writes the changesets of the transitions changed since the last release of gl-transitions
// (see transition-changesets.mjs) into .changeset/. Run before `changeset version`, which
// consumes them; they are never committed.
// Usage: node scripts/npm-package/write-transition-changesets.mjs [repository root]

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { parseTransition } from "../catalog/parse-transition.mjs";
import { transitionChangesets } from "./transition-changesets.mjs";

const ROOT = process.argv[2] ?? path.join(import.meta.dirname, "..", "..");
const git = (...args) => execFileSync("git", args, { cwd: ROOT, encoding: "utf8" }).trim();

// The tag of the current version: changesets tags gl-transitions@<version>, older releases v<version>.
const { version } = JSON.parse(fs.readFileSync(path.join(ROOT, "packages/gl-transitions/package.json"), "utf8"));
const tag = [`gl-transitions@${version}`, `v${version}`].find((t) => {
  try {
    git("rev-parse", "-q", "--verify", `refs/tags/${t}`);
    return true;
  } catch {
    return false;
  }
});
if (!tag) {
  // Not tagged: either the version was just bumped and is not published yet (the changes since
  // are part of it), or its tag is missing, which would stop the transitions from being released.
  let published = false;
  try {
    published =
      execFileSync("npm", ["view", `gl-transitions@${version}`, "version"], { encoding: "utf8" }).trim() !== "";
  } catch {
    // Not on npm.
  }
  if (published) {
    console.error(`gl-transitions ${version} is on npm but has no tag (gl-transitions@${version}): add it`);
    process.exit(1);
  }
  console.log(`gl-transitions ${version} is not published yet: no transition changesets`);
  process.exit(0);
}

const isTransition = (file) => /^transitions\/[^/]+\.glsl$/.test(file);
const nameOf = (file) => path.basename(file, ".glsl");

// What each transition became since the tag: added, changed or removed.
const net = new Map(
  git("diff", "--name-status", "--no-renames", tag, "HEAD", "--", "transitions/")
    .split("\n")
    .filter(Boolean)
    .map((line) => line.split("\t"))
    .filter(([, file]) => isTransition(file))
    .map(([status, file]) => [file, status[0]]),
);

// The commits since the tag, oldest first, with the transitions each one touched.
const commits = git(
  "log",
  "--reverse",
  "--format=@%H",
  "--name-status",
  "--no-renames",
  `${tag}..HEAD`,
  "--",
  "transitions/",
)
  .split("\n@")
  .filter(Boolean)
  .map((block) => {
    const [commit, ...lines] = block.replace(/^@/, "").split("\n");
    const files = lines
      .filter(Boolean)
      .map((line) => line.split("\t"))
      .filter(([, file]) => isTransition(file));
    return { commit, files };
  });

// Renamed and removed transitions (renamed.json) have their own changeset, with the mapping: they
// are not new, nor removed. A rename appears here as the old file removed and the new one added.
const renamedFile = path.join(ROOT, "packages/gl-transitions/renamed.json");
const renamed = fs.existsSync(renamedFile) ? JSON.parse(fs.readFileSync(renamedFile, "utf8")) : {};
// New name → the 1.x names it replaces (a removed duplicate maps to the transition that replaces
// it too), when their files were removed since the tag.
const formerNames = new Map();
for (const [old, now] of Object.entries(renamed)) {
  if (net.get(`transitions/${old}.glsl`) === "D") formerNames.set(now, [...(formerNames.get(now) ?? []), old]);
}
const blob = (rev, file) => {
  try {
    return git("rev-parse", `${rev}:${file}`);
  } catch {
    return null;
  }
};

const changes = [];
for (const [file, status] of net) {
  const name = nameOf(file);
  if (status === "D" && Object.hasOwn(renamed, name)) continue;
  const former = status === "A" && formerNames.get(name);
  if (former) {
    // A renamed transition is listed as updated only if its content changed too.
    if (former.some((old) => blob(tag, `transitions/${old}.glsl`) === blob("HEAD", file))) continue;
    for (const { commit, files } of commits) {
      if (files.some(([, f]) => f === file)) changes.push({ status: "M", name, commit });
    }
    continue;
  }
  if (status === "A") {
    // Credited to the commit that first added it, also when it was renamed since. Git may see that
    // addition as a copy of a similar transition (C): only commits since the tag count, so a
    // transition derived from an older one is still credited to its own commit.
    const commit = git("log", "--follow", "--diff-filter=AC", "--format=%H", `${tag}..HEAD`, "--", file)
      .split("\n")
      .filter(Boolean)
      .pop();
    let author;
    try {
      author = parseTransition(fs.readFileSync(path.join(ROOT, file), "utf8"), path.basename(file)).transition.author;
    } catch {
      // An invalid transition fails the build anyway.
    }
    changes.push({ status, name, author, commit });
  } else {
    // Listed under every commit that changed it, so each pull request gets its entry.
    for (const { commit, files } of commits) {
      if (files.some(([, f]) => f === file)) changes.push({ status, name, commit });
    }
  }
}

const files = transitionChangesets(changes);
for (const { file, content } of files) fs.writeFileSync(path.join(ROOT, ".changeset", file), content);
console.log(`${files.length} changesets for ${net.size} transitions changed since ${tag}`);
