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

**vanilla JSON:**

```
https://unpkg.com/gl-transitions@1/gl-transitions.json
```
