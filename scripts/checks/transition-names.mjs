#!/usr/bin/env node
// The naming rules of transitions (CONTRIBUTING.md, "Naming"), shared by the lint and agents.
// Usage: node scripts/checks/transition-names.mjs <Name> ...  (checks candidate names of new transitions)
//
// A transition's name is its file name without `.glsl`, and its identifier in every package:
// - PascalCase: a capital letter, then letters and digits (`CrossZoom`, `WipeLeft`)
// - acronyms written as words, so never three capitals in a row (`HsvFade`, not `HSVFade`)
// - no `Transition` in the name: everything in the collection is one
// - different from every other name, ignoring case (case-insensitive file systems)
// - never a name of 1.x (packages/gl-transitions/renamed.json) for another transition: code that
//   only fixed the case of an old name would silently get a different effect

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.join(import.meta.dirname, "..", "..");
// 1.x name → 2.0 name (for the two removed duplicates, the transition that replaces them).
const RENAMED = JSON.parse(fs.readFileSync(path.join(ROOT, "packages/gl-transitions/renamed.json"), "utf8"));

// Names compare without case, dashes and underscores (`old_tv` and `OldTv` are the same name).
const key = (name) => name.toLowerCase().replace(/[-_]/g, "");
const formerNames = new Map(Object.entries(RENAMED).map(([old, now]) => [key(old), now]));

// Returns the errors of `name`; `others` are the names of the other transitions.
function nameErrors(name, others = []) {
  const errors = [];
  if (!/^[A-Z][A-Za-z0-9]*$/.test(name)) {
    errors.push(`'${name}' must be PascalCase: a capital letter, then letters and digits (e.g. CrossZoom)`);
  } else if (/[A-Z]{3}/.test(name)) {
    errors.push(`'${name}' has three capitals in a row: write acronyms as words (HsvFade, not HSVFade)`);
  }
  if (/transition/i.test(name)) errors.push(`'${name}' must not contain 'Transition': every entry is one`);
  const same = others.find((other) => other !== name && key(other) === key(name));
  if (same) errors.push(`'${name}' only differs from '${same}' by case: names must differ ignoring case`);
  const now = formerNames.get(key(name));
  if (now && now !== name) {
    errors.push(`'${name}' was the 1.x name of '${now}': pick another name, so old code does not get another effect`);
  }
  return errors;
}

// Run as a script (also through a symlinked path), not when imported by the lint and the tests.
const isMain = process.argv[1] && fs.realpathSync(process.argv[1]) === fs.realpathSync(fileURLToPath(import.meta.url));
if (isMain) {
  const names = process.argv.slice(2).map((n) => path.basename(n, ".glsl"));
  if (!names.length) {
    console.error("Usage: node scripts/checks/transition-names.mjs <Name> ...");
    process.exit(1);
  }
  const existing = fs
    .readdirSync(path.join(ROOT, "transitions"))
    .filter((f) => f.endsWith(".glsl"))
    .map((f) => path.basename(f, ".glsl"));
  let failed = false;
  for (const name of names) {
    const errors = nameErrors(name, existing);
    for (const e of errors) console.error(`Error: ${e}`);
    if (!errors.length)
      console.log(`'${name}' is a valid name${existing.includes(name) ? " (an existing transition)" : ""}`);
    failed ||= errors.length > 0;
  }
  if (failed) process.exit(1);
}

export { nameErrors };
