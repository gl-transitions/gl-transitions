#!/usr/bin/env node
// Validates a gl-transition shader against the spec.
// Usage: node validate-transition.js --transition path/to/fade.glsl
//
// Checks:
// 1. Shader compiles
// 2. progress=0 renders exclusively getFromColor(uv)
// 3. progress=1 renders exclusively getToColor(uv)
// 4. progress=0.5 renders something (not blank)
// 5. No unused uniform parameters
// 6. Has required metadata (Author, License)
// 7. Contains a transition(vec2) function
// 8. Description, Tags and parameter annotations are well formed
//
// Exit code 0 = pass, 1 = errors found
// Outputs JSON to stdout: { name, valid, errors[], warnings[] }

const fs = require("fs");
const path = require("path");
const { parseMeta } = require("../lib/transition-meta");

const args = process.argv.slice(2);
let transitionPath = null;
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--transition" || args[i] === "-t") transitionPath = args[++i];
}
if (!transitionPath) {
  console.error("Usage: validate-transition.js --transition <file.glsl>");
  process.exit(1);
}

const glsl = fs.readFileSync(transitionPath, "utf8");
const name = path.basename(transitionPath, ".glsl");
const errors = [];
const warnings = [];

function fail() {
  console.log(JSON.stringify({ name, valid: false, errors, warnings }, null, 2));
  process.exit(1);
}

// --- Static checks (no GL needed) ---

if (!/\/\/\s*[Aa]uthor\s*:/.test(glsl)) {
  errors.push("Missing '// Author:' comment");
}
if (!/\/\/\s*[Ll]icense\s*:/.test(glsl)) {
  errors.push("Missing '// License:' comment");
}
if (glsl.includes("\r")) {
  errors.push("Use LF line endings, not CRLF");
}
if (!/vec4\s+transition\s*\(\s*vec2/.test(glsl)) {
  errors.push("Missing 'vec4 transition(vec2 uv)' function");
}
// Strip comments before checking for forbidden tokens
const glslNoComments = glsl
  .replace(/\/\/.*$/gm, "")
  .replace(/\/\*[\s\S]*?\*\//g, "");

if (/\bgl_FragColor\b/.test(glslNoComments)) {
  warnings.push("Should not use gl_FragColor — return from transition() instead");
}
if (/\btexture2D\s*\(\s*(from|to)\b/.test(glslNoComments)) {
  warnings.push("Should use getFromColor()/getToColor() instead of texture2D(from/to)");
}
if (/\bresolution\b/.test(glslNoComments)) {
  warnings.push("Uses 'resolution' — gl-transitions provides 'ratio' instead");
}
if (/\bgl_FragCoord\b/.test(glslNoComments)) {
  warnings.push("Uses gl_FragCoord — use the uv parameter from transition(vec2 uv) instead");
}
if (/\bvoid\s+main\s*\(/.test(glslNoComments)) {
  errors.push("Should not define main() — only define transition(vec2 uv)");
}

// Parse declared uniforms
// Handles: uniform float a; | uniform float a, b; | uniform vec3 color /* = ... */;
const declaredUniforms = new Set();
const uniformDeclRegex = /uniform\s+\w+\s+([\w\s,]+?)(?:\s*\/\*.*?\*\/)?\s*;/g;
let m;
while ((m = uniformDeclRegex.exec(glsl)) !== null) {
  m[1].split(",").map(s => s.trim()).filter(Boolean).forEach(n => declaredUniforms.add(n));
}

function parseGLSLValue(type, valueStr) {
  valueStr = valueStr.trim();
  if (type === "bool") return valueStr === "true";
  if (type === "int") return parseInt(valueStr, 10);
  if (type === "float") return parseFloat(valueStr);
  const vecMatch = valueStr.match(/^(i)?vec(\d)\s*\(([^)]+)\)/);
  if (vecMatch) {
    const arity = parseInt(vecMatch[2], 10);
    const parse = vecMatch[1] ? (v) => parseInt(v, 10) : parseFloat;
    const values = vecMatch[3].split(",").map((v) => parse(v.trim()));
    return values.length === 1 && arity > 1 ? Array(arity).fill(values[0]) : values;
  }
  return parseFloat(valueStr);
}

// Parse default values — supports both comment styles:
//   uniform float foo; // = 1.0
//   uniform vec3 color /* = vec3(0.0) */;
const uniformDefaults = {};
const uniformTypes = {};
const defaultRegex = /uniform\s+(bool|int|float|vec[234]|ivec[234]|mat[234]|sampler2D)\s+(\w+)\s*(?:[;,]\s*(?:\/\/\s*=\s*(.+?)(?:\s*;.*)?$)|(?:\s*\/\*\s*=\s*(.+?)\s*\*\/))/gm;
while ((m = defaultRegex.exec(glsl)) !== null) {
  const [, type, uname] = m;
  const val = (m[3] || m[4] || "").trim();
  if (type === "sampler2D") continue;
  uniformTypes[uname] = type;
  if (val) uniformDefaults[uname] = parseGLSLValue(type, val);
}

// Catalog metadata: Description, Tags and parameter annotations
const meta = parseMeta(glsl, uniformTypes, uniformDefaults);
errors.push(...meta.errors);
warnings.push(...meta.warnings);
if (!meta.description) {
  warnings.push("Missing '// Description:' comment (one line describing the effect)");
}
if (meta.tags.length === 0) {
  warnings.push("Missing '// Tags:' comment (e.g. '// Tags: wipe, directional')");
}

// If static checks already found critical errors, skip GL validation
if (errors.some(e => e.includes("transition(vec2"))) fail();

// --- GL validation ---

const createGL = require("gl");
const width = 64;
const height = 64;
const gl = createGL(width, height, { preserveDrawingBuffer: true });
if (!gl) {
  errors.push("Failed to create GL context");
  fail();
}

function compileShader(type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    return { shader: null, error: gl.getShaderInfoLog(shader) };
  }
  return { shader, error: null };
}

const vertSrc = `
attribute vec2 _p;
varying vec2 _uv;
void main() {
  gl_Position = vec4(_p, 0.0, 1.0);
  _uv = vec2(0.5, 0.5) * (_p + vec2(1.0, 1.0));
}`;

// Validation textures: from = vec4(uv, 0, 1), to = vec4(uv, 1, 1)
// This lets us verify that progress=0 shows from and progress=1 shows to
const fragSrc = `
precision highp float;
varying vec2 _uv;
uniform float progress, ratio;
vec4 getFromColor(vec2 uv) { return vec4(uv, 0.0, 1.0); }
vec4 getToColor(vec2 uv) { return vec4(uv, 1.0, 1.0); }
${glsl}
void main() { gl_FragColor = transition(_uv); }`;

const vs = compileShader(gl.VERTEX_SHADER, vertSrc);
if (vs.error) {
  errors.push(`Vertex shader compile error: ${vs.error}`);
  fail();
}

const fragShader = compileShader(gl.FRAGMENT_SHADER, fragSrc);
if (fragShader.error) {
  // Extract meaningful error lines
  const lines = fragShader.error.split("\n").filter(l => l.includes("ERROR"));
  errors.push(`Fragment shader compile error: ${lines.join("; ") || fragShader.error}`);
  fail();
}

const program = gl.createProgram();
gl.attachShader(program, vs.shader);
gl.attachShader(program, fragShader.shader);
gl.linkProgram(program);
if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
  errors.push(`Program link error: ${gl.getProgramInfoLog(program)}`);
  fail();
}
gl.useProgram(program);

const buffer = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, -1, 4, 4, -1]), gl.STATIC_DRAW);
const posLoc = gl.getAttribLocation(program, "_p");
gl.enableVertexAttribArray(posLoc);
gl.vertexAttribPointer(posLoc, 2, gl.FLOAT, false, 0, 0);
gl.viewport(0, 0, width, height);

// Set ratio
const ratioLoc = gl.getUniformLocation(program, "ratio");
if (ratioLoc) gl.uniform1f(ratioLoc, width / height);

// Set default uniform values
const uniformSetters = {
  float: (loc, v) => gl.uniform1f(loc, v),
  int: (loc, v) => gl.uniform1i(loc, v),
  bool: (loc, v) => gl.uniform1i(loc, v ? 1 : 0),
  vec2: (loc, v) => gl.uniform2fv(loc, v),
  vec3: (loc, v) => gl.uniform3fv(loc, v),
  vec4: (loc, v) => gl.uniform4fv(loc, v),
  ivec2: (loc, v) => gl.uniform2iv(loc, v),
  ivec3: (loc, v) => gl.uniform3iv(loc, v),
  ivec4: (loc, v) => gl.uniform4iv(loc, v),
};

// Check for unused uniforms
for (const uname of declaredUniforms) {
  if (["progress", "ratio"].includes(uname)) continue;
  const loc = gl.getUniformLocation(program, uname);
  if (!loc) {
    warnings.push(`Uniform '${uname}' is declared but unused`);
  }
}

for (const [uname, value] of Object.entries(uniformDefaults)) {
  const loc = gl.getUniformLocation(program, uname);
  const type = uniformTypes[uname];
  if (loc && uniformSetters[type]) uniformSetters[type](loc, value);
}

const pixels = new Uint8Array(width * height * 4);
const progressLoc = gl.getUniformLocation(program, "progress");

// Pick 5 sample positions (corners + center, with padding)
const pad = Math.floor(width / 8);
const pickPositions = [
  [pad, pad],
  [width - 1 - pad, pad],
  [pad, height - 1 - pad],
  [width - 1 - pad, height - 1 - pad],
  [Math.floor(width / 2), Math.floor(height / 2)],
];

function colorAt(x, y) {
  const i = (x + y * width) * 4;
  return [pixels[i], pixels[i + 1], pixels[i + 2], pixels[i + 3]];
}

function colorMatches(actual, expected) {
  const dr = actual[0] - expected[0];
  const dg = actual[1] - expected[1];
  const db = actual[2] - expected[2];
  const da = actual[3] - expected[3];
  return dr * dr + dg * dg + db * db + da * da < 30; // fuzzy match for precision differences
}

function expectedFromColor(x, y) {
  const u = Math.round((x / (width - 1)) * 255);
  const v = Math.round((y / (height - 1)) * 255);
  return [u, v, 0, 255];
}

function expectedToColor(x, y) {
  const u = Math.round((x / (width - 1)) * 255);
  const v = Math.round((y / (height - 1)) * 255);
  return [u, v, 255, 255];
}

function drawAndRead(progress) {
  if (progressLoc) gl.uniform1f(progressLoc, progress);
  gl.drawArrays(gl.TRIANGLES, 0, 3);
  gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
}

// Check 1: progress=0 must show from image
drawAndRead(0.0);
const p0Picks = pickPositions.map(([x, y]) => colorAt(x, y));
const p0Expected = pickPositions.map(([x, y]) => expectedFromColor(x, y));
const p0Matches = p0Picks.map((c, i) => colorMatches(c, p0Expected[i]));
if (!p0Matches.every(Boolean)) {
  // Check if it's showing the "to" image instead (swapped)
  const p0ToExpected = pickPositions.map(([x, y]) => expectedToColor(x, y));
  const p0ToMatches = p0Picks.map((c, i) => colorMatches(c, p0ToExpected[i]));
  if (p0ToMatches.every(Boolean)) {
    errors.push("progress=0 shows getToColor instead of getFromColor (from/to swapped)");
  } else {
    errors.push("progress=0 must render exclusively getFromColor(uv)");
  }
}

// Check 2: progress=1 must show to image
drawAndRead(1.0);
const p1Picks = pickPositions.map(([x, y]) => colorAt(x, y));
const p1Expected = pickPositions.map(([x, y]) => expectedToColor(x, y));
const p1Matches = p1Picks.map((c, i) => colorMatches(c, p1Expected[i]));
if (!p1Matches.every(Boolean)) {
  const p1FromExpected = pickPositions.map(([x, y]) => expectedFromColor(x, y));
  const p1FromMatches = p1Picks.map((c, i) => colorMatches(c, p1FromExpected[i]));
  if (p1FromMatches.every(Boolean)) {
    errors.push("progress=1 shows getFromColor instead of getToColor (from/to swapped)");
  } else {
    errors.push("progress=1 must render exclusively getToColor(uv)");
  }
}

// Check 3: progress=0.5 should not be blank (all black or all white)
drawAndRead(0.5);
let allSame = true;
const firstPixel = colorAt(0, 0);
for (let i = 0; i < width * height * 4; i += 4) {
  if (Math.abs(pixels[i] - firstPixel[0]) > 2 ||
      Math.abs(pixels[i + 1] - firstPixel[1]) > 2 ||
      Math.abs(pixels[i + 2] - firstPixel[2]) > 2) {
    allSame = false;
    break;
  }
}
if (allSame) {
  warnings.push("progress=0.5 renders a single solid color — transition may not be working correctly");
}

// Output results
const valid = errors.length === 0;
const result = { name, valid, errors, warnings };
console.log(JSON.stringify(result, null, 2));
process.exit(valid ? 0 : 1);
