#!/usr/bin/env node
// Renders reference images of transitions with the GLSL spec v1 wrapper.
// Each transition becomes one PNG strip of FRAMES frames at increasing progress.
// Other shader targets (SkSL, WGSL, …) are compared against these images.
//
// Usage:
//   node render-references.js --out <dir> [--transitions <dir>] [file.glsl ...]
//   node render-references.js --check --out <dir> [--strict]   # compare with images in <dir>
//
// Without file arguments, renders every transition of --transitions (default: transitions/).
// Input images are generated procedurally so the output only depends on the GL
// implementation. Images are not committed: CI renders the base branch and the PR
// in the same environment and reports transitions whose output changed.
// Exit code 1 on render failures, and with --strict also on changed/missing images.
//
// Requires: gl, pngjs

const fs = require("fs");
const path = require("path");
const { PNG } = require("pngjs");
const { parseTransition } = require("../lib/parse-transition");

const { WIDTH, HEIGHT, PROGRESS, fromImage, toImage, extraImage } = require("../lib/reference-images");

const ROOT = path.join(__dirname, "..", "..");
// --check: a frame differs when more than MAX_BAD_RATIO of its pixels move by more than CHANNEL_TOLERANCE.
const CHANNEL_TOLERANCE = 2;
const MAX_BAD_RATIO = 0.001;

const args = process.argv.slice(2);
let outDir = null;
let transitionsDir = path.join(ROOT, "transitions");
let check = false;
let strict = false;
const files = [];
for (let i = 0; i < args.length; i++) {
  if (args[i] === "--out") outDir = path.resolve(args[++i]);
  else if (args[i] === "--transitions") transitionsDir = path.resolve(args[++i]);
  else if (args[i] === "--check") check = true;
  else if (args[i] === "--strict") strict = true;
  else files.push(path.resolve(args[i]));
}
if (!outDir) {
  console.error("Usage: render-references.js --out <dir> [--check [--strict]] [--transitions <dir>] [file.glsl ...]");
  process.exit(1);
}
if (files.length === 0) {
  const dir = transitionsDir;
  for (const f of fs.readdirSync(dir).sort()) {
    if (f.endsWith(".glsl") && fs.statSync(path.join(dir, f)).isFile()) files.push(path.join(dir, f));
  }
}

// --- GL setup ---

const gl = require("gl")(WIDTH, HEIGHT, { preserveDrawingBuffer: true });
if (!gl) {
  console.error("Failed to create GL context");
  process.exit(1);
}
gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);

function createTexture(unit, rgba) {
  const tex = gl.createTexture();
  gl.activeTexture(gl.TEXTURE0 + unit);
  gl.bindTexture(gl.TEXTURE_2D, tex);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, WIDTH, HEIGHT, 0, gl.RGBA, gl.UNSIGNED_BYTE, rgba);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
}
createTexture(0, fromImage);
createTexture(1, toImage);
createTexture(2, extraImage);

function compile(type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    throw new Error(gl.getShaderInfoLog(shader));
  }
  return shader;
}

const vertexShader = compile(
  gl.VERTEX_SHADER,
  `attribute vec2 _p;
varying vec2 _uv;
void main() {
  gl_Position = vec4(_p, 0.0, 1.0);
  _uv = 0.5 * (_p + 1.0);
}`
);

const buffer = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, -1, 4, 4, -1]), gl.STATIC_DRAW);

const setters = {
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

// Renders the strip as RGBA, row 0 = top.
function renderStrip(file) {
  const glsl = fs.readFileSync(file, "utf8");
  const { transition } = parseTransition(glsl, path.basename(file));
  const fragment = compile(
    gl.FRAGMENT_SHADER,
    `precision highp float;
varying vec2 _uv;
uniform sampler2D from, to;
uniform float progress, ratio;
vec4 getFromColor(vec2 uv) { return texture2D(from, uv); }
vec4 getToColor(vec2 uv) { return texture2D(to, uv); }
${glsl}
void main() { gl_FragColor = transition(_uv); }`
  );
  const program = gl.createProgram();
  gl.attachShader(program, vertexShader);
  gl.attachShader(program, fragment);
  gl.bindAttribLocation(program, 0, "_p");
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    throw new Error(gl.getProgramInfoLog(program));
  }
  gl.useProgram(program);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
  gl.viewport(0, 0, WIDTH, HEIGHT);

  gl.uniform1i(gl.getUniformLocation(program, "from"), 0);
  gl.uniform1i(gl.getUniformLocation(program, "to"), 1);
  for (const name of transition.textures) gl.uniform1i(gl.getUniformLocation(program, name), 2);
  gl.uniform1f(gl.getUniformLocation(program, "ratio"), WIDTH / HEIGHT);
  for (const [name, type] of Object.entries(transition.paramsTypes)) {
    const loc = gl.getUniformLocation(program, name);
    if (loc && setters[type] && name in transition.defaultParams) setters[type](loc, transition.defaultParams[name]);
  }

  const strip = Buffer.alloc(WIDTH * PROGRESS.length * HEIGHT * 4);
  const frame = new Uint8Array(WIDTH * HEIGHT * 4);
  const progressLoc = gl.getUniformLocation(program, "progress");
  PROGRESS.forEach((p, f) => {
    gl.uniform1f(progressLoc, p);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    gl.readPixels(0, 0, WIDTH, HEIGHT, gl.RGBA, gl.UNSIGNED_BYTE, frame);
    for (let y = 0; y < HEIGHT; y++) {
      const src = (HEIGHT - 1 - y) * WIDTH * 4; // GL rows are bottom-up
      const dst = (y * WIDTH * PROGRESS.length + f * WIDTH) * 4;
      strip.set(frame.subarray(src, src + WIDTH * 4), dst);
    }
  });
  gl.deleteProgram(program);
  gl.deleteShader(fragment);
  return strip;
}

function encodePNG(rgba) {
  const png = new PNG({ width: WIDTH * PROGRESS.length, height: HEIGHT });
  png.data = Buffer.from(rgba);
  return PNG.sync.write(png, { colorType: 6 });
}

// Returns the frames (by progress) whose pixels differ beyond tolerance.
function compare(actual, expected) {
  const stripWidth = WIDTH * PROGRESS.length;
  const bad = new Array(PROGRESS.length).fill(0);
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < stripWidth; x++) {
      const i = (y * stripWidth + x) * 4;
      for (let c = 0; c < 4; c++) {
        if (Math.abs(actual[i + c] - expected[i + c]) > CHANNEL_TOLERANCE) {
          bad[Math.floor(x / WIDTH)]++;
          break;
        }
      }
    }
  }
  return PROGRESS.filter((_, f) => bad[f] / (WIDTH * HEIGHT) > MAX_BAD_RATIO);
}

fs.mkdirSync(outDir, { recursive: true });
const report = { rendered: 0, failed: [], changed: [], missing: [] };
for (const file of files) {
  const name = path.basename(file, ".glsl");
  const target = path.join(outDir, `${name}.png`);
  let strip;
  try {
    strip = renderStrip(file);
  } catch (e) {
    report.failed.push({ name, error: String(e.message || e).trim() });
    continue;
  }
  report.rendered++;
  if (!check) {
    fs.writeFileSync(target, encodePNG(strip));
  } else if (!fs.existsSync(target)) {
    report.missing.push(name);
  } else {
    const expected = PNG.sync.read(fs.readFileSync(target));
    // A strip of another size (other renderer settings) can't be compared pixel by pixel.
    const frames =
      expected.width === WIDTH * PROGRESS.length && expected.height === HEIGHT
        ? compare(strip, expected.data)
        : PROGRESS;
    if (frames.length) report.changed.push({ name, progress: frames });
  }
}

console.log(JSON.stringify(report, null, 2));
const ok = report.failed.length === 0 && (!strict || (report.changed.length === 0 && report.missing.length === 0));
process.exit(ok ? 0 : 1);
