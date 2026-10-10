// Parses a gl-transition source into its catalog entry.
// Shared by the build (build-catalog.mjs), the checks and the renderers.

import path from "node:path";
import { parseMeta } from "./transition-meta.mjs";

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
    return values.length === 1 && arity > 1 ? Array(arity).fill(values[0]) : values;
  }

  const num = parseFloat(valueStr);
  if (!isNaN(num)) return num;
  return valueStr;
}

const UNIFORM_STATEMENT = /uniform\s+(bool|int|float|vec[234]|ivec[234]|mat[234]|sampler2D)\s+([^;\n]+);([^\n]*)/g;

// Splits the names part of a uniform statement ("a /* = 1.0 */, b") into
// [{ name, blockDefault }], taking block-comment defaults out first since they may contain commas.
function splitDeclarators(declarators) {
  const blockDefaults = [];
  const names = declarators.replace(/\/\*\s*=\s*(.*?)\s*\*\//g, (_, value) => `@${blockDefaults.push(value) - 1}`);
  return names
    .split(",")
    .map((d) => d.trim().match(/^(\w+)\s*(?:@(\d+))?$/))
    .filter(Boolean)
    .map((m) => ({ name: m[1], blockDefault: m[2] !== undefined ? blockDefaults[Number(m[2])] : undefined }));
}

// Every declared uniform name, with or without a default (sampler2D included).
function parseUniformNames(glsl) {
  return [...glsl.matchAll(UNIFORM_STATEMENT)].flatMap((m) => splitDeclarators(m[2]).map((d) => d.name));
}

function parseTransition(glsl, filename) {
  const name = path.basename(filename, ".glsl");

  const authorMatch = glsl.match(/\/\/\s*[Aa]uthor\s*:\s*(.+)/);
  const author = authorMatch ? authorMatch[1].trim() : "unknown";

  const licenseMatch = glsl.match(/\/\/\s*[Ll]icense\s*:\s*(.+)/);
  const license = licenseMatch ? licenseMatch[1].trim() : "MIT";

  const paramsTypes = {};
  const defaultParams = {};

  // Supported formats (README "Transition parameters"):
  //   uniform float foo; // = 1.0
  //   uniform vec2 foo; // = vec2(1.0, 2.0)
  //   uniform float foo/* = 1.0 */;
  //   uniform vec2 foo /*= vec2(1.0) */, bar /* = vec2(2.0) */;
  //   uniform vec2 foo, bar; // = vec2(1.0, 2.0);   (one default for every name)
  // Only uniforms with a default value are parameters.
  for (const [, type, declarators, rest] of glsl.matchAll(UNIFORM_STATEMENT)) {
    if (type === "sampler2D") continue;
    const lineDefault = rest.match(/^\s*\/\/\s*=\s*(.+?)(?:\s*;.*)?$/);
    for (const { name, blockDefault } of splitDeclarators(declarators)) {
      const defaultValue = blockDefault ?? (lineDefault && lineDefault[1]);
      if (!defaultValue) continue;
      paramsTypes[name] = type;
      defaultParams[name] = parseGLSLValue(type, defaultValue);
    }
  }

  const meta = parseMeta(glsl, paramsTypes, defaultParams);

  return {
    transition: {
      name,
      paramsTypes,
      defaultParams,
      glsl,
      author,
      license,
      description: meta.description,
      tags: meta.tags,
      params: meta.params,
      textures: meta.textures,
    },
    errors: meta.errors,
    warnings: meta.warnings,
  };
}

export { parseGLSLValue, parseTransition, parseUniformNames };
