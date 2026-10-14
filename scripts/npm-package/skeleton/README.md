# gl-transitions

> The open collection of GL Transitions.

Browse all transitions on **[gl-transitions.com](https://gl-transitions.com/)**.

This package exposes an Array<Transition> auto-generated from the [GitHub repository](https://github.com/gl-transitions/gl-transitions).

A Transition is an object with the following shape (TypeScript types are included):

```ts
{
  name: string,          // stable identifier, also the file name
  author: string,
  license: string,
  glsl: string,          // implements vec4 transition(vec2 uv)
  description?: string,
  tags: string[],
  params: {              // one entry per parameter
    [name: string]: {
      type: string,      // "float", "vec2", "bool", ...
      default?: number | boolean | number[],
      min?: number, max?: number, step?: number,  // suggested UI bounds
      color?: boolean,   // the value is a color
      description?: string,
    }
  },
  textures: string[],    // extra sampler2D inputs, beyond from/to
  paramsTypes: { [name: string]: string },   // legacy, prefer params
  defaultParams: { [name: string]: number | boolean | number[] },  // legacy, prefer params
  createdAt: string,
  updatedAt: string,
}
```

## Files

| Path | Content |
|---|---|
| `index.js` | The collection (CommonJS; `import` works too) |
| `gl-transitions.json` | The same, as JSON |
| `gl-transitions.js` | The same, as a `window.GLTransitions` script |
| `transitions/<name>.glsl` | Each transition's GLSL source |
| `sksl/<name>.sksl` | Each transition as a standalone [SkSL](https://skia.org/docs/user/sksl/) runtime effect, for Skia-based renderers (React Native Skia, CanvasKit, Flutter/Skia, Compose Multiplatform, skia-safe) |
| `glsl3/<name>.glsl` | Each transition that compiles in GLSL ES 3.00 (all of them today), for WebGL 2, three.js (`glslVersion: THREE.GLSL3`), OpenGL ES 3 and Android Media3 |
| `wgsl/<name>.wgsl` | Each transition that translates to WGSL, as a fragment shader, for WebGPU |
| `msl/<name>.metal` | Each transition that translates to Metal, as a Metal Shading Language fragment shader |
| `layouts.json` | Uniform buffer layout and textures of the WGSL and Metal shaders |
| `compatibility.json` | Status of every transition in every target (see below) |
| `llms.txt`, `llms-full.txt` | The collection for LLMs and coding agents ([llms.txt](https://llmstxt.org/) format) |
| `skills/gl-transitions/` | An [Agent Skill](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/overview) that teaches coding agents to pick a transition and wire it into WebGL, Skia, editly or FFmpeg |

### GLSL ES 3.00 contract

`glsl3/<name>.glsl` has the same shape as the original GLSL: it declares the parameter uniforms and `vec4 transition(vec2 uv)`, with `texture()` instead of `texture2D()`. The host provides the rest, for example:

```glsl
#version 300 es
precision highp float;
precision highp int;
in vec2 _uv;
out vec4 _fragColor;
uniform sampler2D from, to;
uniform float progress, ratio;
vec4 getFromColor(vec2 uv) { return texture(from, uv); }
vec4 getToColor(vec2 uv) { return texture(to, uv); }
// ... contents of glsl3/<name>.glsl ...
void main() { _fragColor = transition(_uv); }
```

Each file is compiled in this wrapper with glslang, the Khronos reference compiler, in CI.

### WGSL and Metal contract

`wgsl/<name>.wgsl` (WebGPU, three.js WebGPU, Babylon.js, Bevy, wgpu) and `msl/<name>.metal` (Metal: AVFoundation, Core Image, SwiftUI) are complete fragment shaders with the same interface for every transition:

| Resource | WGSL (`@group(0)`) | Metal | Content |
|---|---|---|---|
| Uniform buffer | `@binding(0)` | `[[buffer(0)]]` | `progress`, `ratio`, then each parameter in declaration order (`bool` parameters are `i32`, 0 or 1), with std140 / WGSL uniform layout |
| Sampler | `@binding(1)` | `[[sampler(0)]]` | Used for every texture; linear filtering and clamp to edge give the GLSL behavior |
| `from` image | `@binding(2)` | `[[texture(0)]]` | |
| `to` image | `@binding(3)` | `[[texture(1)]]` | |
| Extra textures | `@binding(4)`, … | `[[texture(2)]]`, … | One per entry of `textures`, in order |
| Input | `@location(0) vec2<f32>` | `[[user(loc0)]]` | uv in [0, 1] with a bottom-left origin, as in the GLSL spec (`0.5 * (position.xy + 1.0)` of a fullscreen triangle) |
| Output | `@location(0) vec4<f32>` | color 0 | Straight (unpremultiplied) RGBA |

The entry point is `main` in WGSL and `main_` in Metal. Images are sampled with a top-left origin (as WebGPU and Metal upload them) at mip level 0. `layouts.json` gives the uniform buffer of every transition: `{ [name]: { uniforms: [{ name, type, offset }], size, textures } }`, with offsets and size in bytes.

In CI, each WGSL file is validated by naga and rendered with Dawn (Chrome's WebGPU) to compare with the GLSL rendering. Metal files are translated by naga from the same SPIR-V; they are compiled with Apple's Metal compiler on macOS during development, not in CI.

### Compatibility

`compatibility.json` says how each transition fares in each target (types: `Compatibility` in `index.d.ts`):

```json
{
  "targets": { "wgsl": { "language": "WGSL", "path": "wgsl/{name}.wgsl", "rendered": true }, ... },
  "transitions": { "fade": { "sksl": { "status": "match", "differingPixels": 0 }, "glsl3": { "status": "compiled" }, ... } }
}
```

| Status | Meaning |
|---|---|
| `match` | Renders like the GLSL reference (at most 1% of pixels differ by more than 16/255) |
| `close` | At most 5% of pixels differ |
| `noise-only` | Same picture with a different random noise grain (hash noise varies between GPUs) |
| `differs` | Renders differently, usually random tiles or shapes picked by hash noise (`hashNoise: true`) |
| `compiled` | Accepted by the target's compiler; not rendered (GLSL ES 3.00, Metal) |
| `translated` | Generated, but the target's compiler was not available in the build |
| `no-reference` | Rendered, but there was no GLSL reference to compare with |
| `compile-error`, `unsupported` | Not shipped for this target; `error` says why |

Files are shipped for every status except the last row.

### SkSL contract

Every `sksl/<name>.sksl` has the same interface:

- children: `_from` and `_to` (the two images, drawn at the output size), then one per entry of `textures`
- uniforms: `float2 _resolution` (output size in pixels), `float progress`, `float ratio`, then each parameter by name (`bool` parameters are `int`, 0 or 1)
- entry point: `half4 main(float2 coord)`, pixel coordinates with a top-left origin; the output is premultiplied

Each file is compiled with Skia and compared against the GLSL rendering in CI.

For more information, please check out the [GitHub repository](https://github.com/gl-transitions/gl-transitions).

## Install

**with npm:**

```sh
npm install gl-transitions
# or
yarn add gl-transitions
```

```js
import GLTransitions from "gl-transitions";
```

**dist script:**

```
https://unpkg.com/gl-transitions@1/gl-transitions.js
```

```js
const GLTransitions = window.GLTransitions
```

**for coding agents:**

```
https://cdn.jsdelivr.net/npm/gl-transitions@1/llms.txt
```

To install the Agent Skill, copy `node_modules/gl-transitions/skills/gl-transitions` into your agent's skills folder (for Claude Code: `.claude/skills/`).

**vanilla JSON:**

```
https://unpkg.com/gl-transitions@1/gl-transitions.json
```
