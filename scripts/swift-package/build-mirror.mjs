#!/usr/bin/env node
// Writes the content of the gl-transitions-swift repository (https://github.com/gl-transitions/gl-transitions-swift),
// where CI publishes the Swift package with each release: swift/ with its generated catalog, without
// the gl-transitions-check executable (scripts/swift-package/check.mjs), and its README pointing
// here for development. Its version is that of the npm package.
// Usage: node scripts/swift-package/build-mirror.mjs --package <the npm package> --out <empty folder>

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const ROOT = path.join(import.meta.dirname, "..", "..");
const SWIFT = path.join(ROOT, "swift");
const args = process.argv.slice(2);
let pkg;
let out;
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--package") pkg = path.resolve(args[++i]);
  else if (args[i] === "--out") out = path.resolve(args[++i]);
}
if (!pkg || !out) {
  console.error("Usage: node scripts/swift-package/build-mirror.mjs --package <the npm package> --out <empty folder>");
  process.exit(2);
}
if (fs.existsSync(out) && fs.readdirSync(out).length > 0) {
  console.error(`${out} is not empty`);
  process.exit(1);
}
const { version } = JSON.parse(fs.readFileSync(path.join(pkg, "package.json"), "utf8"));

function replace(text, pattern, replacement, what) {
  if (!pattern.test(text)) throw new Error(`${what} not found`);
  return text.replace(pattern, replacement);
}

fs.mkdirSync(out, { recursive: true });
fs.cpSync(path.join(SWIFT, "Sources/GLTransitions"), path.join(out, "Sources/GLTransitions"), {
  recursive: true,
  filter: (src) => src !== path.join(SWIFT, "Sources/GLTransitions/Generated"),
});
fs.cpSync(path.join(SWIFT, "Tests"), path.join(out, "Tests"), { recursive: true });
fs.copyFileSync(path.join(SWIFT, "LICENSE"), path.join(out, "LICENSE"));

const manifest = fs.readFileSync(path.join(SWIFT, "Package.swift"), "utf8");
fs.writeFileSync(
  path.join(out, "Package.swift"),
  replace(
    manifest,
    /\n(?:[ \t]*\/\/[^\n]*\n)*[ \t]*\.executableTarget\(name: "gl-transitions-check"[^\n]*/,
    "",
    "The gl-transitions-check target of swift/Package.swift",
  ),
);

let readme = fs.readFileSync(path.join(SWIFT, "README.md"), "utf8");
readme = replace(
  readme,
  /(\.package\(url: "https:\/\/github\.com\/gl-transitions\/gl-transitions-swift", from: ")[^"]+/,
  `$1${version}`,
  "The installation of swift/README.md",
);
readme = replace(
  readme,
  /\n## Development\n[\s\S]*?(?=\n## |$)/,
  `
## Development

This repository is a read-only mirror, published with each release of the [gl-transitions npm package](https://www.npmjs.com/package/gl-transitions) (same version). The package is developed in the [gl-transitions repository](https://github.com/gl-transitions/gl-transitions/tree/master/swift): issues and pull requests go there.
`,
  "The Development section of swift/README.md",
);
fs.writeFileSync(path.join(out, "README.md"), readme);

execFileSync(
  process.execPath,
  [path.join(import.meta.dirname, "build-swift-package.mjs"), "--package", pkg, "--out", out],
  { stdio: "inherit" },
);
