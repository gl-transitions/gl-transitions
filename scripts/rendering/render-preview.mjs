#!/usr/bin/env node
// Renders a gl-transition to a GIF preview.
// Usage: pnpm run render:preview --transition path/to/Fade.glsl --output preview.gif [--output-black preview.black.gif] [--seed 42]
//
// Its three photos are drawn at random; the same seed (an integer) gives the same photos.
//
// GIF transparency is all or nothing, so soft shadows and reflections can't show in a transparent
// GIF: a transition that leaves parts of the frame transparent is drawn over white in --output,
// and over black in --output-black.
//
// Requires: gl npm package, ffmpeg system binary

import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";
import { randomInt } from "node:crypto";
import { parseTransition } from "../catalog/parse-transition.mjs";
import { choosePreviewImages, previewImagePath } from "./preview-images.mjs";

const args = process.argv.slice(2);
let transitionPath = null;
let outputPath = "preview.gif";
let blackOutputPath = null;
let seed = randomInt(2 ** 32);
let width = 400;
let height = 300;
let frames = 34;
const delay = 6;
// GIF delays are in hundredths of a second: 20 fps is exact, 30 fps is not.
const fps = 20;

for (let i = 0; i < args.length; i++) {
  if (args[i] === "--transition" || args[i] === "-t") transitionPath = args[++i];
  else if (args[i] === "--output" || args[i] === "-o") outputPath = args[++i];
  else if (args[i] === "--output-black") blackOutputPath = args[++i];
  else if (args[i] === "--seed") seed = Number(args[++i]);
  else if (args[i] === "--width" || args[i] === "-w") width = parseInt(args[++i]);
  else if (args[i] === "--height") height = parseInt(args[++i]);
  else if (args[i] === "--frames" || args[i] === "-f") frames = parseInt(args[++i]);
}

if (!transitionPath || !Number.isSafeInteger(seed) || seed < 0) {
  console.error("Usage: pnpm run render:preview --transition <file.glsl> [--output <out.gif>] [--seed <integer>]");
  process.exit(1);
}

const transitionGlsl = fs.readFileSync(transitionPath, "utf8");
const transitionName = path.basename(transitionPath, ".glsl");

const uniformSetters = {
  float: (gl, loc, v) => gl.uniform1f(loc, v),
  int: (gl, loc, v) => gl.uniform1i(loc, v),
  bool: (gl, loc, v) => gl.uniform1i(loc, v ? 1 : 0),
  vec2: (gl, loc, v) => gl.uniform2fv(loc, v),
  vec3: (gl, loc, v) => gl.uniform3fv(loc, v),
  vec4: (gl, loc, v) => gl.uniform4fv(loc, v),
  ivec2: (gl, loc, v) => gl.uniform2iv(loc, v),
  ivec3: (gl, loc, v) => gl.uniform3iv(loc, v),
  ivec4: (gl, loc, v) => gl.uniform4iv(loc, v),
};

const { default: createGL } = await import("gl");
const gl = createGL(width, height, { preserveDrawingBuffer: true });
if (!gl) {
  console.error("Failed to create GL context");
  process.exit(1);
}
gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);

function compileShader(type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    throw new Error(`Shader compile error:\n${gl.getShaderInfoLog(shader)}`);
  }
  return shader;
}

const vertSrc = `
attribute vec2 position;
varying vec2 _uv;
void main() {
  gl_Position = vec4(position, 0.0, 1.0);
  _uv = 0.5 * (position + 1.0);
}`;

const fragSrc = `
precision highp float;
varying vec2 _uv;
uniform sampler2D from, to;
uniform float progress;
uniform float ratio;
vec4 getFromColor(vec2 uv) { return texture2D(from, uv); }
vec4 getToColor(vec2 uv) { return texture2D(to, uv); }
${transitionGlsl}
void main() { gl_FragColor = transition(_uv); }`;

const vs = compileShader(gl.VERTEX_SHADER, vertSrc);
const fragShader = compileShader(gl.FRAGMENT_SHADER, fragSrc);
const program = gl.createProgram();
gl.attachShader(program, vs);
gl.attachShader(program, fragShader);
gl.linkProgram(program);
if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
  throw new Error("Program link error: " + gl.getProgramInfoLog(program));
}
gl.useProgram(program);

const buffer = gl.createBuffer();
gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, -1, 4, 4, -1]), gl.STATIC_DRAW);
const posLoc = gl.getAttribLocation(program, "position");
gl.enableVertexAttribArray(posLoc);
gl.vertexAttribPointer(posLoc, 2, gl.FLOAT, false, 0, 0);

function createTexture(rgba, w, h) {
  const tex = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, tex);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, rgba);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  return tex;
}

function loadImage(imgPath, w, h) {
  const raw = execSync(
    `ffmpeg -v fatal -i "${imgPath}" -vf "scale=${w}:${h}:force_original_aspect_ratio=increase,crop=${w}:${h}" -f rawvideo -pix_fmt rgba -`,
    { maxBuffer: w * h * 4 + 1024 },
  );
  return new Uint8Array(raw.buffer, raw.byteOffset, raw.byteLength);
}

const images = choosePreviewImages(seed);
console.error(`Photos: ${images.join(", ")} (--seed ${seed})`);
const textures = images.map((image) => createTexture(loadImage(previewImagePath(image), width, height), width, height));

const progressLoc = gl.getUniformLocation(program, "progress");
gl.uniform1f(gl.getUniformLocation(program, "ratio"), width / height);
gl.uniform1i(gl.getUniformLocation(program, "from"), 0);
gl.uniform1i(gl.getUniformLocation(program, "to"), 1);

const { transition } = parseTransition(transitionGlsl, path.basename(transitionPath));
for (const [name, type] of Object.entries(transition.paramsTypes)) {
  const value = transition.defaultParams[name];
  const loc = gl.getUniformLocation(program, name);
  if (loc && uniformSetters[type]) uniformSetters[type](gl, loc, value);
}

gl.viewport(0, 0, width, height);

// Render 3 transitions: A->B, B->C, C->A (seamless loop)
const segments = [
  [0, 1],
  [1, 2],
  [2, 0],
];
const framesPerSegment = delay + frames;
const totalFrames = framesPerSegment * segments.length;
const pixelData = new Uint8Array(width * height * 4);
const flipped = new Uint8Array(width * height * 4);
const rowSize = width * 4;
const allFrames = Buffer.alloc(totalFrames * width * height * 4);

console.error(`Rendering ${transitionName}: ${totalFrames} frames, 3 segments (${width}x${height})`);

let frameIndex = 0;
for (const [fromIdx, toIdx] of segments) {
  gl.activeTexture(gl.TEXTURE0);
  gl.bindTexture(gl.TEXTURE_2D, textures[fromIdx]);
  gl.activeTexture(gl.TEXTURE1);
  gl.bindTexture(gl.TEXTURE_2D, textures[toIdx]);

  for (let i = 0; i < framesPerSegment; i++) {
    const p = i < delay ? 0.0 : (i - delay) / (frames - 1);

    gl.uniform1f(progressLoc, p);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
    gl.readPixels(0, 0, width, height, gl.RGBA, gl.UNSIGNED_BYTE, pixelData);

    for (let y = 0; y < height; y++) {
      flipped.set(pixelData.subarray(y * rowSize, y * rowSize + rowSize), (height - 1 - y) * rowSize);
    }
    allFrames.set(flipped, frameIndex * width * height * 4);
    frameIndex++;
  }
}

// The frames of a hold are the same: the GIF has the first one, shown longer.
const filters = `select=not(between(mod(n\\,${framesPerSegment})\\,1\\,${delay})),scale=320:-1:flags=lanczos`;
const encode = (output, background) => {
  const input = background
    ? `-filter_complex "color=c=${background}:s=${width}x${height}:r=${fps}[bg];[bg][0]overlay=shortest=1:format=auto,`
    : `-vf "`;
  execSync(
    `ffmpeg -v fatal -f rawvideo -pix_fmt rgba -s ${width}x${height} -framerate ${fps} -i pipe:0 ${input}${filters},split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse=dither=bayer:bayer_scale=3" -fps_mode vfr -gifflags -offsetting-transdiff -loop 0 -y "${output}"`,
    { input: allFrames, maxBuffer: 100 * 1024 * 1024 },
  );
  const size = fs.statSync(output).size;
  console.error(`Generated ${output} (${(size / 1024).toFixed(0)} KB)`);
};
let transparent = false;
for (let i = 3; i < allFrames.length && !transparent; i += 4) transparent = allFrames[i] < 255;
try {
  encode(outputPath, transparent ? "white" : null);
  if (blackOutputPath && transparent) encode(blackOutputPath, "black");
} catch (e) {
  console.error("ffmpeg error:", e.stderr?.toString() || e.message);
  process.exit(1);
}
console.log(path.resolve(outputPath));
