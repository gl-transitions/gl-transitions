# WebGL

A transition is the body of a fragment shader. Put it between a header that defines the contextual variables and a `main` that calls `transition`. This works in WebGL 1 and WebGL 2 (a WebGL 2 context also accepts GLSL ES 1.00 shaders, as long as they have no `#version` line), and in OpenGL ES hosts. For desktop OpenGL (GLSL 1.20), drop the `precision` line.

## Shaders

```js
const vertexShader = `
attribute vec2 _p;
varying vec2 _uv;
void main() {
  gl_Position = vec4(_p, 0.0, 1.0);
  _uv = _p * 0.5 + 0.5;
}`;

// transition.glsl is the source of one transition (e.g. transitions.find(t => t.name === "cube").glsl).
const fragmentShader = (transitionGlsl) => `
precision highp float;
varying vec2 _uv;
uniform sampler2D from, to;
uniform float progress, ratio, _fromR, _toR;

// Sample like CSS object-fit: cover (_fromR, _toR: width / height of each image).
vec4 getFromColor(vec2 uv) {
  return texture2D(from, 0.5 + (uv - 0.5) * vec2(min(ratio / _fromR, 1.0), min(_fromR / ratio, 1.0)));
}
vec4 getToColor(vec2 uv) {
  return texture2D(to, 0.5 + (uv - 0.5) * vec2(min(ratio / _toR, 1.0), min(_toR / ratio, 1.0)));
}

${transitionGlsl}

void main() {
  gl_FragColor = transition(_uv);
}`;
```

When both images already have the canvas aspect ratio, `getFromColor(uv)` can simply be `texture2D(from, uv)`.

## Drawing

```js
function createTransition(gl, transition) {
  const compile = (type, src) => {
    const s = gl.createShader(type);
    gl.shaderSource(s, src);
    gl.compileShader(s);
    if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s));
    return s;
  };
  const program = gl.createProgram();
  gl.attachShader(program, compile(gl.VERTEX_SHADER, vertexShader));
  gl.attachShader(program, compile(gl.FRAGMENT_SHADER, fragmentShader(transition.glsl)));
  gl.bindAttribLocation(program, 0, "_p");
  gl.linkProgram(program);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program));

  const buffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW); // one full-screen triangle

  const loc = (name) => gl.getUniformLocation(program, name);

  // Parameters: the user's value, else the default from the catalog. Never leave one unset.
  function setParams(values = {}) {
    for (const [name, p] of Object.entries(transition.params)) {
      const v = [].concat(values[name] ?? p.default ?? 0).map(Number); // bool -> 0/1
      const n = v.length;
      if (/^(int|bool|ivec)/.test(p.type) || p.type.startsWith("bvec")) gl[`uniform${n}iv`](loc(name), v);
      else if (p.type.startsWith("mat")) gl[`uniformMatrix${Math.sqrt(n)}fv`](loc(name), false, v);
      else gl[`uniform${n}fv`](loc(name), v);
    }
  }

  // from, to: { texture, width, height }. extra: { [textureName]: WebGLTexture } for transition.textures.
  return function draw(progress, from, to, params = {}, extra = {}) {
    gl.useProgram(program);
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);
    const textures = [["from", from.texture], ["to", to.texture], ...transition.textures.map((t) => [t, extra[t]])];
    textures.forEach(([name, texture], unit) => {
      gl.activeTexture(gl.TEXTURE0 + unit);
      gl.bindTexture(gl.TEXTURE_2D, texture);
      gl.uniform1i(loc(name), unit);
    });
    gl.uniform1f(loc("progress"), progress);
    gl.uniform1f(loc("ratio"), gl.drawingBufferWidth / gl.drawingBufferHeight);
    gl.uniform1f(loc("_fromR"), from.width / from.height);
    gl.uniform1f(loc("_toR"), to.width / to.height);
    setParams(params);
    gl.viewport(0, 0, gl.drawingBufferWidth, gl.drawingBufferHeight);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  };
}

// Images (or video frames, canvases): flip rows so uv (0, 0) is the bottom left of the image.
function createTexture(gl, source) {
  const texture = gl.createTexture();
  gl.bindTexture(gl.TEXTURE_2D, texture);
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, source);
  // CLAMP_TO_EDGE and no mipmaps: required for non-power-of-two images in WebGL 1.
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  // Intrinsic size first: an <img> or <video> width/height may be its displayed size.
  const width = source.naturalWidth || source.videoWidth || source.width;
  const height = source.naturalHeight || source.videoHeight || source.height;
  return { texture, width, height };
}
```

Animate with `requestAnimationFrame`, computing `progress` from elapsed time (clamped to [0, 1], optionally eased). For video, call `createTexture` once and re-upload each frame with `texImage2D`.

## Existing libraries

- [`gl-transition`](https://www.npmjs.com/package/gl-transition): `createTransition(gl, transition)` for any WebGL context (used by editly).
- [`regl-transition`](https://www.npmjs.com/package/regl-transition) and [`react-gl-transition`](https://www.npmjs.com/package/react-gl-transition) for regl and gl-react.

They are older but follow the same specification; the recipe above has no dependency.
