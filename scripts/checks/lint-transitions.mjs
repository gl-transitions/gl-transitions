#!/usr/bin/env node
// Checks the layout and encoding of the transitions/ folder.
// Usage: pnpm run lint  (or: node scripts/checks/lint-transitions.mjs [transitions-dir])
//
// - every entry is a regular `.glsl` file directly in transitions/ (the GitHub
//   web UI sometimes creates `Foo.glsl/Foo.glsl` or drops the extension)
// - UTF-8 without BOM, LF line endings (see encoding.mjs)
// - the header and parameters parse without errors, as the build requires
//   (annotations, typed defaults such as `true`/`false` for bool, author; see catalog/parse-transition.mjs)
// - the file name follows the naming rules (PascalCase, unique ignoring case; see transition-names.mjs)
// Hidden files (.DS_Store, …) are ignored, like the rest of the tooling does.

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { checkEncoding } from "./encoding.mjs";
import { parseTransition } from "../catalog/parse-transition.mjs";
import { nameErrors } from "./transition-names.mjs";

// Returns { count, errors } for the transitions in `dir`.
function lintTransitions(dir) {
  const entries = fs
    .readdirSync(dir, { withFileTypes: true })
    .filter((e) => !e.name.startsWith("."))
    .sort((a, b) => a.name.localeCompare(b.name));
  const errors = [];
  const names = entries
    .filter((e) => e.isFile() && e.name.endsWith(".glsl"))
    .map((e) => path.basename(e.name, ".glsl"));
  for (const entry of entries) {
    const rel = path.join(path.basename(dir), entry.name);
    if (!entry.isFile()) {
      errors.push(
        `${rel}: must be a file directly in transitions/ (found a ${entry.isDirectory() ? "directory" : "non-file"})`,
      );
      continue;
    }
    if (!entry.name.endsWith(".glsl")) {
      errors.push(`${rel}: must have the .glsl extension`);
      continue;
    }
    for (const e of nameErrors(path.basename(entry.name, ".glsl"), names)) errors.push(`${rel}: ${e}`);
    const buffer = fs.readFileSync(path.join(dir, entry.name));
    for (const e of checkEncoding(buffer)) errors.push(`${rel}: ${e}`);
    for (const e of parseTransition(buffer.toString("utf8"), entry.name).errors) errors.push(`${rel}: ${e}`);
  }
  return { count: entries.length, errors };
}

// Run as a script (also through a symlinked path), not when imported by the tests.
const isMain = process.argv[1] && fs.realpathSync(process.argv[1]) === fs.realpathSync(fileURLToPath(import.meta.url));
if (isMain) {
  const dir = process.argv[2] || path.join(import.meta.dirname, "..", "..", "transitions");
  const { count, errors } = lintTransitions(dir);
  for (const e of errors) console.error(`Error: ${e}`);
  if (errors.length) process.exit(1);
  console.log(`Linted ${count} transitions`);
}

export { lintTransitions };
