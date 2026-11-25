// Times the frames of transitions on a WebGL 1 context: Chrome's (benchmark-page.mjs) or headless
// gl's (benchmark-transitions.mjs).

const VERTEX = `attribute vec2 _p;
varying vec2 _uv;
void main() {
  gl_Position = vec4(_p, 0.0, 1.0);
  _uv = 0.5 * (_p + 1.0);
}`;

const fragmentSource = (glsl) => `precision highp float;
varying vec2 _uv;
uniform sampler2D from, to;
uniform float progress, ratio;
vec4 getFromColor(vec2 uv) { return texture2D(from, uv); }
vec4 getToColor(vec2 uv) { return texture2D(to, uv); }
${glsl}
void main() { gl_FragColor = transition(_uv); }`;

// How long each measure lasts: many frames, so that the fixed costs don't matter.
const MEASURE_MS = 25;
const MAX_FRAMES = 120;
const ROUNDS = 4;
const TRANSITION_SECONDS = 60;
// The references measured on each side of a run, for a run of one transition.
const REFERENCES = 3;

// `images`: from, to, and the one of the transitions' extra sampler2D, as { width, height, data }.
// Returns measureAll.
function createFrameTimer(gl, { width, height, progress, images }) {
  const texture = (image) => {
    const result = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, result);
    const { width: w, height: h, data } = image ?? { width, height, data: null };
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, w, h, 0, gl.RGBA, gl.UNSIGNED_BYTE, data);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    return result;
  };
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
  const inputs = images.map(texture);
  // Two targets drawn in turn: a driver could skip a frame drawn over before being used.
  const targets = [0, 1].map(() => {
    const target = texture(null);
    const framebuffer = gl.createFramebuffer();
    gl.bindFramebuffer(gl.FRAMEBUFFER, framebuffer);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, target, 0);
    return framebuffer;
  });
  inputs.forEach((input, unit) => {
    gl.activeTexture(gl.TEXTURE0 + unit);
    gl.bindTexture(gl.TEXTURE_2D, input);
  });
  gl.bindBuffer(gl.ARRAY_BUFFER, gl.createBuffer());
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
  gl.viewport(0, 0, width, height);

  const setters = {
    float: (location, v) => gl.uniform1f(location, v),
    int: (location, v) => gl.uniform1i(location, v),
    bool: (location, v) => gl.uniform1i(location, v ? 1 : 0),
    vec2: (location, v) => gl.uniform2fv(location, v),
    vec3: (location, v) => gl.uniform3fv(location, v),
    vec4: (location, v) => gl.uniform4fv(location, v),
    ivec2: (location, v) => gl.uniform2iv(location, v),
    ivec3: (location, v) => gl.uniform3iv(location, v),
    ivec4: (location, v) => gl.uniform4iv(location, v),
  };

  function compile(program, type, source) {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader));
    gl.attachShader(program, shader);
    gl.deleteShader(shader);
  }

  function build({ glsl, paramsTypes, defaultParams, textures }) {
    const program = gl.createProgram();
    compile(program, gl.VERTEX_SHADER, VERTEX);
    compile(program, gl.FRAGMENT_SHADER, fragmentSource(glsl));
    gl.bindAttribLocation(program, 0, "_p");
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program));
    gl.useProgram(program);
    const location = (name) => gl.getUniformLocation(program, name);
    gl.uniform1i(location("from"), 0);
    gl.uniform1i(location("to"), 1);
    for (const name of textures) gl.uniform1i(location(name), 2);
    gl.uniform1f(location("ratio"), width / height);
    for (const [name, type] of Object.entries(paramsTypes)) {
      const at = location(name);
      if (at && setters[type]) setters[type](at, defaultParams[name]);
    }
    return program;
  }

  const pixel = new Uint8Array(4);
  // Waits for the GPU.
  const finish = () => gl.readPixels(0, 0, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixel);
  function frameTime(frames) {
    finish();
    const start = performance.now();
    for (let i = 0; i < frames; i++) {
      gl.bindFramebuffer(gl.FRAMEBUFFER, targets[i % 2]);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
    }
    finish();
    return (performance.now() - start) / frames;
  }

  // Throws when it isn't done `seconds` later: a frame can take seconds on the CPU.
  function measure(transition, seconds) {
    const end = performance.now() + seconds * 1000;
    const program = build(transition);
    const location = gl.getUniformLocation(program, "progress");
    const ms = progress.map(() => Infinity);
    // In rounds, so that a spike of the machine's load doesn't hit every measure of a frame.
    for (let round = 0; round < ROUNDS; round++) {
      progress.forEach((p, i) => {
        if (performance.now() > end) throw new Error(`too slow to measure in ${seconds} s`);
        gl.uniform1f(location, p);
        frameTime(1);
        let pilot = frameTime(2);
        // Waiting for the GPU is a large part of 2 cheap frames.
        if (pilot < 2) pilot = frameTime(10);
        const frames = Math.max(2, Math.min(MAX_FRAMES, Math.ceil(MEASURE_MS / Math.max(0.05, pilot))));
        ms[i] = Math.min(ms[i], frameTime(frames));
      });
    }
    gl.deleteProgram(program);
    if (gl.isContextLost()) throw new Error("the GPU context was lost");
    return ms;
  }

  // Measures each transition, with the reference around it, since the machine's speed changes
  // along the run; `report` gets each measure in order, a transition's or a reference's. Stops
  // after `seconds`. Throws when no more can be measured.
  return async function measureAll(reference, transitions, seconds, report) {
    const end = performance.now() + seconds * 1000;
    const reportReferences = async (count) => {
      for (let i = 0; i < count; i++) {
        await report({ reference: true, ms: measure(reference, TRANSITION_SECONDS) });
      }
    };
    await reportReferences(REFERENCES);
    for (const transition of transitions) {
      const { name } = transition;
      const left = (end - performance.now()) / 1000;
      if (left <= 0) throw new Error(`stopped after ${seconds} s`);
      try {
        await report({ name, ms: measure(transition, Math.min(TRANSITION_SECONDS, Math.ceil(left))) });
      } catch (e) {
        await report({ name, error: String(e.message || e).trim() });
        if (gl.isContextLost()) throw new Error(`the GPU context was lost by ${name}`);
      }
      await reportReferences(1);
    }
    await reportReferences(REFERENCES - 1);
  };
}

// The renderer's name, as the driver gives it.
function rendererName(gl) {
  const info = gl.getExtension("WEBGL_debug_renderer_info");
  return String(gl.getParameter(info ? info.UNMASKED_RENDERER_WEBGL : gl.RENDERER));
}

export { createFrameTimer, rendererName };
