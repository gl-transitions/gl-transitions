// Parses a gl-transition source into its catalog entry.
// Shared by gl-transition-transform.js (build) and the reference renderer.

const path = require("path");
const { parseMeta } = require("./transition-meta");

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

  // Supported formats (README "Transition parameters"):
  //   uniform float foo; // = 1.0
  //   uniform vec2 foo; // = vec2(1.0, 2.0)
  //   uniform float foo/* = 1.0 */;
  //   uniform vec2 foo /*= vec2(1.0) */, bar /* = vec2(2.0) */;
  //   uniform vec2 foo, bar; // = vec2(1.0, 2.0);   (one default for every name)
  // Only uniforms with a default value are parameters.
  const uniformRegex =
    /uniform\s+(bool|int|float|vec[234]|ivec[234]|mat[234]|sampler2D)\s+([^;\n]+);([^\n]*)/g;

  let match;
  while ((match = uniformRegex.exec(glsl)) !== null) {
    const [, type, declarators, rest] = match;
    if (type === "sampler2D") continue;

    const lineDefault = rest.match(/^\s*\/\/\s*=\s*(.+?)(?:\s*;.*)?$/);
    // Block comments may contain commas (vec2(1.0, 2.0)): take them out before splitting names.
    const blockDefaults = [];
    const names = declarators.replace(/\/\*\s*=\s*(.*?)\s*\*\//g, (_, value) => `@${blockDefaults.push(value) - 1}`);
    for (const declarator of names.split(",")) {
      const m = declarator.trim().match(/^(\w+)\s*(?:@(\d+))?$/);
      if (!m) continue;
      const defaultValue = m[2] !== undefined ? blockDefaults[Number(m[2])] : lineDefault && lineDefault[1];
      if (!defaultValue) continue;
      paramsTypes[m[1]] = type;
      defaultParams[m[1]] = parseGLSLValue(type, defaultValue);
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

module.exports = { parseGLSLValue, parseTransition };
