// Converts a gl-transition (GLSL spec v1) into a standalone SkSL runtime effect.
//
// Contract of the generated shader (same for every transition):
//   children:  uniform shader _from, _to;   then one per extra texture, in `textures` order
//   uniforms:  float2 _resolution  (output size in pixels)
//              float progress, ratio
//              one per parameter, same name; bool parameters become int (0 or 1)
//   entry:     half4 main(float2 coord), coord in pixels with a top-left origin
// Children are sampled with uv in [0, 1] scaled by _resolution, so every child
// image must be drawn at the output size. Like the GLSL spec, transitions see
// straight (unpremultiplied) colors; the output is premultiplied as Skia expects.

import { preprocess } from "./glsl-preprocess.mjs";

function header(t) {
  const lines = [
    `// ${t.name} — generated from https://github.com/gl-transitions/gl-transitions/blob/master/transitions/${t.name}.glsl`,
    `// Author: ${t.author}`,
    `// License: ${t.license}`,
  ];
  if (t.description) lines.push(`// Description: ${t.description}`);
  return lines.join("\n");
}

const WRAPPER = `uniform shader _from;
uniform shader _to;
uniform float2 _resolution;
uniform float progress;
uniform float ratio;

vec4 getFromColor(vec2 uv) { return vec4(unpremul(_from.eval(vec2(uv.x, 1.0 - uv.y) * _resolution))); }
vec4 getToColor(vec2 uv) { return vec4(unpremul(_to.eval(vec2(uv.x, 1.0 - uv.y) * _resolution))); }
`;

const MAIN = `
half4 main(float2 _coord) {
  vec2 _uv = _coord / _resolution;
  vec4 _c = clamp(transition(vec2(_uv.x, 1.0 - _uv.y)), 0.0, 1.0);
  return half4(_c.rgb * _c.a, _c.a);
}
`;

function replaceIdentifier(src, name, replacement) {
  return src.replace(new RegExp(`(?<![\\w.])${name}\\b`, "g"), replacement);
}

function toSkSL(transition) {
  let body = preprocess(transition.glsl);

  // Extra textures: `uniform sampler2D x;` -> child shader + helper; texture2D(x, uv) -> helper call.
  const helpers = [];
  for (const name of transition.textures) {
    helpers.push(
      `vec4 _texture_${name}(vec2 uv) { return vec4(unpremul(${name}.eval(vec2(uv.x, 1.0 - uv.y) * _resolution))); }`,
    );
    body = body.replace(new RegExp(`\\btexture2D\\s*\\(\\s*${name}\\s*,`, "g"), `_texture_${name}(`);
  }
  body = body.replace(/uniform\s+sampler2D\s+([\w\s,]+);/g, (_, names) =>
    names
      .split(",")
      .map((n) => `uniform shader ${n.trim()};`)
      .join("\n"),
  );
  if (/\btexture2D\s*\(/.test(body)) {
    throw new Error("texture2D() is only supported on declared extra textures");
  }

  // SkSL has no bool uniforms: declare them as int and compare against 0 where used.
  for (const [name, type] of Object.entries(transition.paramsTypes)) {
    if (type !== "bool") continue;
    const decl = new RegExp(`uniform\\s+bool\\s+${name}\\s*;`);
    if (!decl.test(body)) throw new Error(`bool parameter '${name}' must be declared alone to be converted`);
    body = replaceIdentifier(body, name, `(${name} != 0)`);
    body = body.replace(new RegExp(`uniform\\s+bool\\s+\\(${name} != 0\\)\\s*;`), `uniform int ${name};`);
  }

  // Extra texture helpers must follow the child declarations they use.
  if (helpers.length) {
    const lastDecl = [...body.matchAll(/uniform shader \w+;\n?/g)].pop();
    const at = lastDecl.index + lastDecl[0].length;
    body = body.slice(0, at) + helpers.join("\n") + "\n" + body.slice(at);
  }

  const source = `${header(transition)}\n\n${WRAPPER}\n${body.replace(/\n{3,}/g, "\n\n").trim()}\n${MAIN}`;
  return source;
}

export { toSkSL };
