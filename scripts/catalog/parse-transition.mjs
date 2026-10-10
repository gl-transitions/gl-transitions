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

const NUMBER = String.raw`[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?`;
const INTEGER = String.raw`[+-]?\d+`;
const DEFAULT_PATTERNS = {
  bool: /^(?:true|false)$/,
  int: new RegExp(`^${INTEGER}$`),
  float: new RegExp(`^${NUMBER}$`),
};

// Returns why a default value written in the source can't be read as `type`, or null.
// parseGLSLValue is lenient (a bool `= 1` silently reads as false), so the build rejects these.
function checkDefault(type, valueStr) {
  valueStr = valueStr.trim();
  const vecMatch = type.match(/^(i)?vec(\d)$/);
  if (vecMatch) {
    const component = vecMatch[1] ? INTEGER : NUMBER;
    const m = valueStr.match(new RegExp(`^${type}\\s*\\(([^)]*)\\)$`));
    const values = m ? m[1].split(",").map((v) => v.trim()) : [];
    const arityOk = values.length === 1 || values.length === Number(vecMatch[2]);
    if (m && arityOk && values.every((v) => new RegExp(`^${component}$`).test(v))) return null;
    return `expected ${type}(…) with 1 or ${vecMatch[2]} ${vecMatch[1] ? "integers" : "numbers"}`;
  }
  const pattern = DEFAULT_PATTERNS[type];
  if (!pattern || pattern.test(valueStr)) return null;
  return type === "bool" ? "expected true or false" : `expected a${type === "int" ? "n integer" : " number"}`;
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
  const errors = [];
  // A colon reads as another "key: value" header line to tools that parse these comments.
  if (author.includes(":")) errors.push(`Author '${author}' must not contain ':' (e.g. 'name (gitlab.com/handle)')`);

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
      const invalid = checkDefault(type, defaultValue);
      if (invalid) errors.push(`default of '${name}' (${defaultValue.trim()}) is not a valid ${type}: ${invalid}`);
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
    errors: [...errors, ...meta.errors],
    warnings: meta.warnings,
  };
}

export { checkDefault, parseGLSLValue, parseTransition, parseUniformNames };
