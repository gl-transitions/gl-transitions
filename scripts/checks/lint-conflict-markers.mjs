#!/usr/bin/env node
// Fails when a tracked file still contains git merge conflict markers
// (a rebase once committed `<<<<<<< HEAD` into the package README).
// Usage: node scripts/checks/lint-conflict-markers.mjs  (run by `npm run lint`)
//
// Only the `<<<<<<< ` and `>>>>>>> ` markers (and diff3's `||||||| `) are checked:
// a line of seven `=` is also a valid Markdown heading underline.
// Binary files (anything with a NUL byte) are skipped.

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const markerLine = /^(<{7}|>{7}|\|{7})( |$)/;

// Returns the `line: marker` errors found in `text`.
function findConflictMarkers(text) {
  const errors = [];
  text.split("\n").forEach((line, i) => {
    if (markerLine.test(line)) errors.push(`line ${i + 1}: merge conflict marker \`${line.slice(0, 7)}\``);
  });
  return errors;
}

// Returns { count, errors } for the files git tracks in `root`.
function lintConflictMarkers(root) {
  const files = execFileSync("git", ["ls-files", "-z"], { cwd: root, encoding: "utf8" }).split("\0").filter(Boolean);
  const errors = [];
  for (const file of files) {
    const full = path.join(root, file);
    if (!fs.statSync(full, { throwIfNoEntry: false })?.isFile()) continue;
    const buffer = fs.readFileSync(full);
    if (buffer.includes(0)) continue;
    for (const e of findConflictMarkers(buffer.toString("utf8"))) errors.push(`${file}: ${e}`);
  }
  return { count: files.length, errors };
}

// Run as a script (also through a symlinked path), not when imported by the tests.
const isMain = process.argv[1] && fs.realpathSync(process.argv[1]) === fs.realpathSync(fileURLToPath(import.meta.url));
if (isMain) {
  const { count, errors } = lintConflictMarkers(process.argv[2] || path.join(import.meta.dirname, "..", ".."));
  for (const e of errors) console.error(`Error: ${e}`);
  if (errors.length) process.exit(1);
  console.log(`No merge conflict markers in ${count} files`);
}

export { findConflictMarkers, lintConflictMarkers };
