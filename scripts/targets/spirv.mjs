// Turns a gl-transition into a Vulkan GLSL 4.50 fragment shader with a fixed
// binding layout, compiled to SPIR-V by glslang and translated by naga into the
// WGSL and MSL targets. The layout is the public contract of those targets:
//
//   binding 0  uniform buffer, std140 (same offsets in WGSL): progress, ratio, then
//              each parameter in declaration order; bool parameters are int (0 or 1)
//   binding 1  sampler shared by every texture (linear filtering, clamp to edge)
//   binding 2  `_from` texture, binding 3 `_to` texture, then one per extra texture
//              (`textures` of gl-transitions.json), same name, from binding 4
//   location 0 input: uv in [0, 1] with a bottom-left origin, as in the GLSL spec
//   location 0 output: straight (unpremultiplied) RGBA
// All in bind group / set 0. Textures are sampled with a top-left origin (WebGPU,
// Metal and Vulkan convention): the wrapper flips uv.y before sampling.

import { preprocess } from "./glsl-preprocess.mjs";
import { toGLSL3 } from "./glsl3.mjs";

// std140 alignment and size in bytes. Matches WGSL's uniform address space rules for these types.
const STD140 = {
  float: [4, 4],
  int: [4, 4],
  bool: [4, 4],
  vec2: [8, 8],
  ivec2: [8, 8],
  vec3: [16, 12],
  ivec3: [16, 12],
  vec4: [16, 16],
  ivec4: [16, 16],
};

const FIRST_EXTRA_TEXTURE_BINDING = 4;

// Uniform buffer layout: [{ name, type, offset }] and the buffer size, rounded up to 16 bytes.
function uniformLayout(transition) {
  const members = [["progress", "float"], ["ratio", "float"], ...Object.entries(transition.paramsTypes)];
  let offset = 0;
  const uniforms = members.map(([name, type]) => {
    if (!STD140[type]) throw new Error(`parameter type '${type}' is not supported in the uniform buffer`);
    const [align, size] = STD140[type];
    offset = Math.ceil(offset / align) * align;
    const member = { name, type, offset };
    offset += size;
    return member;
  });
  return { uniforms, size: Math.ceil(offset / 16) * 16 };
}

function replaceIdentifier(src, name, replacement) {
  return src.replace(new RegExp(`(?<![\\w.])${name}\\b`, "g"), replacement);
}

// Explicit level 0: WGSL only allows implicit-derivative sampling in uniform control flow,
// and transitions sample inside branches. The images are expected without mipmaps anyway.
function sample(texture, uv) {
  return `textureLod(sampler2D(${texture}, _sampler), vec2(${uv}.x, 1.0 - ${uv}.y), 0.0)`;
}

function toVulkanGLSL(transition) {
  const layout = uniformLayout(transition);
  let body = preprocess(toGLSL3(transition));

  // Parameters move into the uniform buffer.
  for (const [name, type] of Object.entries(transition.paramsTypes)) {
    const decl = new RegExp(`uniform\\s+${type}\\s+${name}\\s*;`);
    if (!decl.test(body)) throw new Error(`parameter '${name}' must be declared alone to be converted`);
    body = body.replace(decl, "");
    if (type === "bool") body = replaceIdentifier(body, name, `(${name} != 0)`);
  }

  // Extra textures: separate texture bindings, sampled through a helper.
  const textures = transition.textures.map((name, k) => {
    const decl = new RegExp(`uniform\\s+sampler2D\\s+${name}\\s*;`);
    if (!decl.test(body)) throw new Error(`texture '${name}' must be declared alone to be converted`);
    body = body.replace(
      decl,
      `layout(set = 0, binding = ${FIRST_EXTRA_TEXTURE_BINDING + k}) uniform texture2D ${name};\n` +
        `vec4 _texture_${name}(vec2 uv) { return ${sample(name, "uv")}; }`,
    );
    body = body.replace(new RegExp(`\\btexture\\s*\\(\\s*${name}\\s*,\\s*`, "g"), `_texture_${name}(`);
    return name;
  });
  if (/(?<![\w.])texture\s*\(\s*(?!sampler2D\s*\()/.test(body)) {
    throw new Error("texture() is only supported on declared extra textures");
  }

  const glslType = (type) => (type === "bool" ? "int" : type);
  const block = layout.uniforms.map((u) => `  ${glslType(u.type)} ${u.name};`).join("\n");
  const source = `#version 450
layout(location = 0) in vec2 _uv;
layout(location = 0) out vec4 _fragColor;
layout(std140, set = 0, binding = 0) uniform Uniforms {
${block}
};
layout(set = 0, binding = 1) uniform sampler _sampler;
layout(set = 0, binding = 2) uniform texture2D _from;
layout(set = 0, binding = 3) uniform texture2D _to;
vec4 getFromColor(vec2 uv) { return ${sample("_from", "uv")}; }
vec4 getToColor(vec2 uv) { return ${sample("_to", "uv")}; }
${body.replace(/\n{3,}/g, "\n\n").trim()}
void main() { _fragColor = transition(_uv); }
`;
  return { source, layout: { ...layout, textures } };
}

// glslang names SPIR-V functions by their mangled signature (`transition(vf2;`), which naga
// writes as `transition_u0028_vf2_u003b`, and naga calls the anonymous uniform block
// `unnamed`. Restores readable names where they don't clash with another identifier.
function tidyNames(code) {
  const renames = new Map([["unnamed", "uniforms"]]);
  const byName = new Map();
  for (const [full, name] of code.matchAll(/\b([A-Za-z_]\w*?)_u0028_\w*?_u003b\b/g)) {
    if (!byName.has(name)) byName.set(name, new Set());
    byName.get(name).add(full);
  }
  for (const [name, fulls] of byName) if (fulls.size === 1) renames.set([...fulls][0], name);
  for (const [from, to] of renames) {
    if (new RegExp(`\\b${to}\\b`).test(code)) continue;
    code = code.replace(new RegExp(`\\b${from}\\b`, "g"), to);
  }
  return code;
}

// naga's command line leaves Metal resource bindings as placeholders (`[[user(fake0)]]`):
// assigns them from the layout (buffer 0 = uniforms, sampler 0, textures from, to, then extras).
function bindMetalResources(msl, layout) {
  const textures = ["_from", "_to", ...layout.textures];
  return msl.replace(/(\s(\w+)) \[\[user\(fake\d+\)\]\]/g, (match, decl, name) => {
    if (name === "_sampler") return `${decl} [[sampler(0)]]`;
    if (textures.includes(name)) return `${decl} [[texture(${textures.indexOf(name)})]]`;
    return `${decl} [[buffer(0)]]`; // the uniform block, the only other resource
  });
}

export { toVulkanGLSL, uniformLayout, tidyNames, bindMetalResources, FIRST_EXTRA_TEXTURE_BINDING };
