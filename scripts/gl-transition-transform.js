#!/usr/bin/env node
// Standalone GLSL transition transform script.
// Produces the same JSON format as gl-transition-scripts' gl-transition-transform,
// without requiring the native `gl` module.
// Temporary solution until gl-transition-libs is updated.

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const { parseTransition } = require("./lib/parse-transition");

const args = process.argv.slice(2);
let transitionsDir = "transitions";
let outputFile = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === "-d" && args[i + 1]) transitionsDir = args[++i];
  else if (args[i] === "-o" && args[i + 1]) outputFile = args[++i];
}

function getGitDatesMap(dir) {
  const created = {};
  const updated = {};

  try {
    // Single git command for all creation dates
    const createdLog = execSync(
      `git log --diff-filter=A --format="%aD" --name-only -- "${dir}"/*.glsl`,
      { encoding: "utf8", maxBuffer: 10 * 1024 * 1024 }
    );
    let currentDate = null;
    for (const line of createdLog.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      if (!trimmed.includes("/")) {
        currentDate = trimmed;
      } else {
        const basename = path.basename(trimmed);
        if (!created[basename]) created[basename] = currentDate;
      }
    }

    // Single git command for all last-modified dates
    const updatedLog = execSync(
      `git log --format="%aD" --name-only -- "${dir}"/*.glsl`,
      { encoding: "utf8", maxBuffer: 10 * 1024 * 1024 }
    );
    currentDate = null;
    for (const line of updatedLog.split("\n")) {
      const trimmed = line.trim();
      if (!trimmed) continue;
      if (!trimmed.includes("/")) {
        currentDate = trimmed;
      } else {
        const basename = path.basename(trimmed);
        if (!updated[basename]) updated[basename] = currentDate;
      }
    }
  } catch {
    process.stderr.write("Warning: could not retrieve git dates\n");
  }

  return { created, updated };
}

const files = fs
  .readdirSync(transitionsDir)
  .filter((f) => f.endsWith(".glsl") && fs.statSync(path.join(transitionsDir, f)).isFile())
  .sort();

const dates = getGitDatesMap(transitionsDir);

let errorCount = 0;
const transitions = files.map((file) => {
  const filepath = path.join(transitionsDir, file);
  const glsl = fs.readFileSync(filepath, "utf8");
  const { transition, errors, warnings } = parseTransition(glsl, file);
  for (const w of warnings) process.stderr.write(`Warning: ${file}: ${w}\n`);
  for (const e of errors) process.stderr.write(`Error: ${file}: ${e}\n`);
  errorCount += errors.length;
  return {
    ...transition,
    createdAt: dates.created[file] || undefined,
    updatedAt: dates.updated[file] || undefined,
  };
});

if (errorCount > 0) {
  process.stderr.write(`${errorCount} annotation error(s), aborting\n`);
  process.exit(1);
}

const json = JSON.stringify(transitions);

if (outputFile) {
  fs.writeFileSync(outputFile, json);
} else {
  process.stdout.write(json);
}

process.stderr.write(`Parsed ${transitions.length} transitions\n`);
