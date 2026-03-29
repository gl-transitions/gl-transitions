#!/usr/bin/env node
// Standalone GLSL transition transform script.
// Produces the same JSON format as gl-transition-scripts' gl-transition-transform,
// without requiring the native `gl` module.
// Temporary solution until gl-transition-libs is updated.

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");

const args = process.argv.slice(2);
let transitionsDir = "transitions";
let outputFile = null;

for (let i = 0; i < args.length; i++) {
  if (args[i] === "-d" && args[i + 1]) transitionsDir = args[++i];
  else if (args[i] === "-o" && args[i + 1]) outputFile = args[++i];
}

function parseGLSLValue(type, valueStr) {
  valueStr = valueStr.trim();
  if (type === "bool") return valueStr === "true";
  if (type === "int") return parseInt(valueStr, 10);
  if (type === "float") return parseFloat(valueStr);

  // vec2/vec3/vec4/ivec2/ivec3/ivec4 — handles broadcast: vec2(0.5) -> [0.5, 0.5]
  const vecMatch = valueStr.match(/^(i)?vec(\d)\s*\(([^)]+)\)/);
  if (vecMatch) {
    const arity = parseInt(vecMatch[2], 10);
    const parse = vecMatch[1] ? (v) => parseInt(v, 10) : parseFloat;
    const values = vecMatch[3].split(",").map((v) => parse(v.trim()));
    return values.length === 1 && arity > 1
      ? Array(arity).fill(values[0])
      : values;
  }

  const num = parseFloat(valueStr);
  if (!isNaN(num)) return num;
  return valueStr;
}

function parseTransition(glsl, filename) {
  const name = path.basename(filename, ".glsl");

  const authorMatch = glsl.match(/\/\/\s*[Aa]uthor\s*:\s*(.+)/);
  const author = authorMatch ? authorMatch[1].trim() : "unknown";

  const licenseMatch = glsl.match(/\/\/\s*[Ll]icense\s*:\s*(.+)/);
  const license = licenseMatch ? licenseMatch[1].trim() : "MIT";

  const paramsTypes = {};
  const defaultParams = {};

  // Supported formats:
  //   uniform float foo; // = 1.0
  //   uniform vec2 foo; // = vec2(1.0, 2.0)
  //   uniform float foo/* = 1.0 */;
  const uniformRegex =
    /uniform\s+(bool|int|float|vec[234]|ivec[234]|mat[234]|sampler2D)\s+(\w+)\s*[;,]\s*(?:\/\/\s*=\s*(.+?)(?:\s*;.*)?$|\/\*\s*=\s*(.+?)\s*\*\/)/gm;

  let match;
  while ((match = uniformRegex.exec(glsl)) !== null) {
    const type = match[1];
    const paramName = match[2];
    const defaultValue = match[3] || match[4];

    if (type === "sampler2D") continue;

    paramsTypes[paramName] = type;
    if (defaultValue) {
      defaultParams[paramName] = parseGLSLValue(type, defaultValue);
    }
  }

  return { name, paramsTypes, defaultParams, glsl, author, license };
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
  .filter((f) => f.endsWith(".glsl"))
  .sort();

const dates = getGitDatesMap(transitionsDir);

const transitions = files.map((file) => {
  const filepath = path.join(transitionsDir, file);
  const glsl = fs.readFileSync(filepath, "utf8");
  const parsed = parseTransition(glsl, file);
  return {
    ...parsed,
    createdAt: dates.created[file] || undefined,
    updatedAt: dates.updated[file] || undefined,
  };
});

const json = JSON.stringify(transitions);

if (outputFile) {
  fs.writeFileSync(outputFile, json);
} else {
  process.stdout.write(json);
}

process.stderr.write(`Parsed ${transitions.length} transitions\n`);
