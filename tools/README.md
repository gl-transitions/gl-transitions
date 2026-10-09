# gl-transitions tools

Builds the collection into other shader languages and checks each output against the GLSL reference renders (`scripts/preview/render-references.js`).

```sh
cd tools && npm install
node build-sksl.js --out /tmp/sksl --refs /tmp/refs/glsl --renders /tmp/sksl-renders --report /tmp/sksl.json
```

CI runs this in the **Reference renders** workflow and posts the results to the job summary.

## SkSL

`build-sksl.js` converts each transition into a standalone [SkSL](https://skia.org/docs/user/sksl/) runtime effect, compiles it with Skia (CanvasKit), renders it with the same input images as the GLSL reference and compares the two.

### Shader contract

Every generated `.sksl` file has the same interface:

| | Name | Notes |
|---|---|---|
| child | `_from`, `_to` | The two images, drawn at the output size |
| child | one per extra texture | Same name as the GLSL `sampler2D` (listed in `textures` of `gl-transitions.json`) |
| uniform | `float2 _resolution` | Output size in pixels |
| uniform | `float progress`, `float ratio` | As in the GLSL spec |
| uniform | each parameter | Same name and type; `bool` parameters are `int` (0 or 1) |
| entry | `half4 main(float2 coord)` | Pixel coordinates, top-left origin |

Transitions see straight (unpremultiplied) colors, as in the GLSL spec; the output is premultiplied, as Skia expects.

### Conversion

1. Preprocess (`lib/preprocess.js`): strip comments, expand `#define` macros, drop `#ifdef GL_ES` blocks.
2. Map extra `sampler2D` inputs to child shaders and `texture2D(x, uv)` to a sampling helper.
3. Turn `bool` uniforms into `int` uniforms.
4. Add the wrapper (children, uniforms, `getFromColor` / `getToColor`, `main`).

### Comparison statuses

| Status | Meaning |
|---|---|
| `match` | At most 1% of pixels differ by more than 16/255 in every frame |
| `close` | At most 5% |
| `noise-only` | Uses hash noise (`fract(sin(x) * 43758.5453)`) and matches when compared as 10×10 block averages |
| `differs` | Anything else. Transitions flagged `hashNoise` pick random tiles or shapes, which legitimately differ between implementations |
| `compile-error` | Skia rejected the generated shader |
| `unsupported` | The converter can't handle the source |
