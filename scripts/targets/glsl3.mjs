// Converts a gl-transition (GLSL spec v1, GLSL ES 1.00) into GLSL ES 3.00.
//
// The output keeps the spec v1 shape so hosts can reuse their wrapper: it declares
// the parameter uniforms (with their `// = default` comments) and
// `vec4 transition(vec2 uv)`, and expects the host to declare `progress`, `ratio`,
// `getFromColor` and `getToColor` after `#version 300 es` and a precision
// (see GLSL3_WRAPPER). The only change from GLSL ES 1.00 is `texture2D` -> `texture`:
// sources that use other ES 1.00-only features are rejected by glslang in the build.

const GLSL3_WRAPPER = {
  before: `#version 300 es
precision highp float;
precision highp int;
in vec2 _uv;
out vec4 _fragColor;
uniform sampler2D from, to;
uniform float progress, ratio;
vec4 getFromColor(vec2 uv) { return texture(from, uv); }
vec4 getToColor(vec2 uv) { return texture(to, uv); }
`,
  after: `
void main() { _fragColor = transition(_uv); }
`,
};

function header(t) {
  return `// ${t.name} — GLSL ES 3.00, generated from https://github.com/gl-transitions/gl-transitions/blob/master/transitions/${t.name}.glsl`;
}

function toGLSL3(transition) {
  if (/^\s*#\s*version\b/m.test(transition.glsl)) throw new Error("#version must be left to the host");
  const body = transition.glsl.replace(/\btexture2D(\s*\()/g, "texture$1");
  return `${header(transition)}\n${body.trimEnd()}\n`;
}

export { toGLSL3, GLSL3_WRAPPER };
