// Parses the optional metadata annotations of a gl-transition source.
// Shared by gl-transition-transform.js (build) and validate-transition.js (PR checks).
//
// Header lines (next to `// Author:` and `// License:`):
//   // Description: The outgoing image falls and bounces on the floor
//   // Tags: bounce, physics
//
// Parameter hints, on comment lines directly above a uniform declaration.
// Text after the hints is the parameter's description; @param alone marks a
// description-only line:
//   // @range(1, 10, 1) Number of bounces before settling
//   uniform float bounces; // = 3.0
//   // @param Wipe from right to left instead
//   uniform bool reversed; // = false
//
// Hints sit on their own line because gl-transitions.com's parser rejects
// anything after the default value on the uniform line.

const NUMERIC_TYPES = ["float", "int", "vec2", "vec3", "vec4", "ivec2", "ivec3", "ivec4"];
const COLOR_TYPES = ["vec3", "vec4"];
const TAG_PATTERN = /^[a-z0-9]+(-[a-z0-9]+)*$/;

function parseHeader(glsl) {
  const errors = [];
  const descriptionMatch = glsl.match(/^\s*\/\/\s*[Dd]escription\s*:\s*(.*)$/m);
  const description = descriptionMatch ? descriptionMatch[1].trim() : undefined;
  if (descriptionMatch && !description) errors.push("'// Description:' is empty");

  const tagsMatch = glsl.match(/^\s*\/\/\s*[Tt]ags\s*:\s*(.*)$/m);
  const tags = [];
  if (tagsMatch) {
    for (const raw of tagsMatch[1].split(",")) {
      const tag = raw.trim().toLowerCase();
      if (!tag) continue;
      if (!TAG_PATTERN.test(tag)) {
        errors.push(`Tag '${tag}' must be lowercase letters, digits and dashes (e.g. 'zoom-in')`);
      } else if (!tags.includes(tag)) {
        tags.push(tag);
      }
    }
    if (tags.length === 0 && errors.length === 0) errors.push("'// Tags:' is empty");
  }

  return { description: description || undefined, tags, errors };
}

// Parses one annotation comment body such as "@range(0, 1) @color Shadow color".
function parseAnnotationLine(body, lineNumber) {
  const hint = {};
  const errors = [];
  let rest = body.trim();
  let m;
  while ((m = rest.match(/^@(\w+)(?:\s*\(([^)]*)\))?\s*/))) {
    const [whole, key, args] = m;
    rest = rest.slice(whole.length);
    if (key === "range") {
      const nums = (args || "").split(",").map((s) => s.trim()).filter(Boolean).map(Number);
      if ((nums.length !== 2 && nums.length !== 3) || nums.some((n) => !Number.isFinite(n))) {
        errors.push(`line ${lineNumber}: @range expects (min, max) or (min, max, step), got '@range(${args || ""})'`);
        continue;
      }
      const [min, max, step] = nums;
      if (min >= max) errors.push(`line ${lineNumber}: @range min (${min}) must be lower than max (${max})`);
      if (step !== undefined && step <= 0) errors.push(`line ${lineNumber}: @range step must be positive`);
      hint.min = min;
      hint.max = max;
      if (step !== undefined) hint.step = step;
    } else if (key === "param") {
      // Marker for a description-only annotation: "// @param What this does"
      if (args !== undefined) errors.push(`line ${lineNumber}: @param takes no arguments`);
    } else if (key === "color") {
      if (args !== undefined) errors.push(`line ${lineNumber}: @color takes no arguments`);
      hint.color = true;
    } else {
      errors.push(`line ${lineNumber}: unknown annotation '@${key}' (supported: @param, @range, @color)`);
    }
  }
  if (rest) hint.description = rest;
  return { hint, errors };
}

// Returns { hints: { [uniformName]: hint }, errors: [] }.
function parseParamAnnotations(glsl) {
  const hints = {};
  const errors = [];
  const lines = glsl.split("\n");
  let pending = null; // { hint, line } collected from consecutive annotation lines

  lines.forEach((line, i) => {
    const lineNumber = i + 1;
    const annotation = line.match(/^\s*\/\/\s*(@\w+.*)$/);
    if (annotation) {
      const { hint, errors: lineErrors } = parseAnnotationLine(annotation[1], lineNumber);
      errors.push(...lineErrors);
      if (!pending) pending = { hint: {}, line: lineNumber };
      if (hint.description && pending.hint.description) {
        hint.description = pending.hint.description + " " + hint.description;
      }
      Object.assign(pending.hint, hint);
      return;
    }
    if (!pending) return;
    if (/^\s*\/\//.test(line)) return; // plain comments may sit between hints and the uniform
    const uniform = line.replace(/\/\*.*?\*\//g, "").match(/^\s*uniform\s+\w+\s+([\w\s,]+);/);
    if (uniform) {
      for (const name of uniform[1].split(",").map((s) => s.trim()).filter(Boolean)) {
        hints[name] = { ...pending.hint };
      }
    } else {
      errors.push(`line ${pending.line}: annotation must be directly above a uniform declaration`);
    }
    pending = null;
  });
  if (pending) errors.push(`line ${pending.line}: annotation must be directly above a uniform declaration`);

  return { hints, errors };
}

// Combines parsed types and defaults with hints into the `params` catalog entry.
function buildParams(paramsTypes, defaultParams, hints) {
  const params = {};
  const errors = [];
  const warnings = [];

  for (const name of Object.keys(hints)) {
    if (!(name in paramsTypes)) errors.push(`annotation targets '${name}', which is not a parameter`);
  }

  for (const [name, type] of Object.entries(paramsTypes)) {
    const hint = hints[name] || {};
    const param = { type };
    if (name in defaultParams) param.default = defaultParams[name];

    if ("min" in hint) {
      if (!NUMERIC_TYPES.includes(type)) {
        errors.push(`@range is not supported on '${name}' (${type})`);
      } else {
        param.min = hint.min;
        param.max = hint.max;
        if ("step" in hint) param.step = hint.step;
        const values = [].concat(param.default ?? []);
        if (values.some((v) => v < hint.min || v > hint.max)) {
          warnings.push(`default of '${name}' is outside its @range(${hint.min}, ${hint.max})`);
        }
      }
    }
    if (hint.color) {
      if (!COLOR_TYPES.includes(type)) errors.push(`@color requires vec3 or vec4, '${name}' is ${type}`);
      else param.color = true;
    }
    if (hint.description) param.description = hint.description;
    params[name] = param;
  }

  return { params, errors, warnings };
}

// Extra texture inputs beyond from/to, declared as `uniform sampler2D name;`.
function parseTextures(glsl) {
  const textures = [];
  const re = /uniform\s+sampler2D\s+([\w\s,]+?)\s*;/g;
  let m;
  while ((m = re.exec(glsl)) !== null) {
    for (const name of m[1].split(",").map((s) => s.trim()).filter(Boolean)) textures.push(name);
  }
  return textures;
}

function parseMeta(glsl, paramsTypes, defaultParams) {
  const header = parseHeader(glsl);
  const annotations = parseParamAnnotations(glsl);
  const built = buildParams(paramsTypes, defaultParams, annotations.hints);
  return {
    description: header.description,
    tags: header.tags,
    params: built.params,
    textures: parseTextures(glsl),
    errors: [...header.errors, ...annotations.errors, ...built.errors],
    warnings: built.warnings,
  };
}

module.exports = { parseHeader, parseParamAnnotations, buildParams, parseTextures, parseMeta };
