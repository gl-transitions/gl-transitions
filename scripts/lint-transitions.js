#!/usr/bin/env node
// Checks the layout and encoding of the transitions/ folder.
// Usage: node scripts/lint-transitions.js [transitions-dir]
//
// - every entry is a regular `.glsl` file directly in transitions/ (the GitHub
//   web UI sometimes creates `Foo.glsl/Foo.glsl` or drops the extension)
// - UTF-8 without BOM
// - LF line endings (CRLF breaks line-based tooling and shows up as noise in diffs)

const fs = require("fs");
const path = require("path");

const dir = process.argv[2] || path.join(__dirname, "..", "transitions");
const errors = [];

for (const entry of fs.readdirSync(dir, { withFileTypes: true }).sort((a, b) => a.name.localeCompare(b.name))) {
  const rel = path.join(path.basename(dir), entry.name);
  if (!entry.isFile()) {
    errors.push(`${rel}: must be a file directly in transitions/ (found a ${entry.isDirectory() ? "directory" : "non-file"})`);
    continue;
  }
  if (!entry.name.endsWith(".glsl")) {
    errors.push(`${rel}: must have the .glsl extension`);
    continue;
  }
  const bytes = fs.readFileSync(path.join(dir, entry.name));
  if (bytes[0] === 0xef && bytes[1] === 0xbb && bytes[2] === 0xbf) {
    errors.push(`${rel}: remove the UTF-8 byte order mark`);
  }
  const text = bytes.toString("utf8");
  if (text.includes("�")) errors.push(`${rel}: must be UTF-8 encoded`);
  if (text.includes("\r")) errors.push(`${rel}: use LF line endings, not CRLF`);
}

if (errors.length) {
  for (const e of errors) console.error(`Error: ${e}`);
  process.exit(1);
}
console.log(`Linted ${fs.readdirSync(dir).length} transitions`);
