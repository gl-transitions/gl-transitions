# Skia (SkSL)

`sksl/<name>.sksl` in the npm package is a complete Skia runtime effect: no wrapper to write. Each file is compiled with Skia and compared against the GLSL rendering in the repository's CI.

## Contract (same for every file)

| | Name | Notes |
|---|---|---|
| child shaders | `_from`, `_to`, then one per name in the transition's `textures` | Each image drawn **at the output size** (scale it to the output rectangle) |
| uniform | `float2 _resolution` | Output size in pixels |
| uniform | `float progress`, `float ratio` | `ratio` = width / height |
| uniform | each parameter, same name | `bool` parameters are `int` (0 or 1) |
| entry | `half4 main(float2 coord)` | Pixel coordinates, top-left origin; output is premultiplied |

The effect flips `uv` internally, so images are drawn the usual Skia way (no manual flip).

## CanvasKit (browser or Node)

Load the SkSL source. In Node:

```js
import fs from "node:fs";
const loadSksl = async (name) => fs.readFileSync(`node_modules/gl-transitions/sksl/${name}.sksl`, "utf8");
```

In the browser (CanvasKit also needs `locateFile` to find its `.wasm`, see its README):

```js
const loadSksl = (name) => fetch(`https://cdn.jsdelivr.net/npm/gl-transitions@1/sksl/${name}.sksl`).then((r) => r.text());
```

Then, in both:

```js
import CanvasKitInit from "canvaskit-wasm";
import transitions from "gl-transitions";

const CanvasKit = await CanvasKitInit();
const transition = transitions.find((t) => t.name === "cube");
const sksl = await loadSksl(transition.name);
let error = "";
const effect = CanvasKit.RuntimeEffect.Make(sksl, (e) => (error += e));
if (!effect) throw new Error(error);

const width = 640, height = 400;
const surface = CanvasKit.MakeSurface(width, height);

// An image as a child shader, stretched to the output size.
const imageShader = (image) =>
  image.makeShaderOptions(
    CanvasKit.TileMode.Clamp, CanvasKit.TileMode.Clamp,
    CanvasKit.FilterMode.Linear, CanvasKit.MipmapMode.None,
    CanvasKit.Matrix.scaled(width / image.width(), height / image.height()),
  );

// Uniforms are a flat float array in declaration order: fill it by name.
function uniforms(values) {
  const out = new Float32Array(effect.getUniformFloatCount());
  for (let i = 0; i < effect.getUniformCount(); i++) {
    const { slot } = effect.getUniform(i);
    [].concat(values[effect.getUniformName(i)] ?? 0).forEach((v, k) => (out[slot + k] = Number(v)));
  }
  return out;
}

// extraImages: one image per transition.textures entry, in that order (e.g. the luma map of `luma`).
function draw(progress, fromImage, toImage, params = {}, extraImages = []) {
  const values = { _resolution: [width, height], progress, ratio: width / height };
  for (const [name, p] of Object.entries(transition.params)) values[name] = params[name] ?? p.default; // never unset
  const children = [fromImage, toImage, ...extraImages].map(imageShader);
  const shader = effect.makeShaderWithChildren(uniforms(values), children);
  const paint = new CanvasKit.Paint();
  paint.setShader(shader);
  const canvas = surface.getCanvas();
  canvas.clear(CanvasKit.TRANSPARENT); // don't blend over the previous frame
  canvas.drawPaint(paint);
  paint.delete();
  shader.delete();
  children.forEach((c) => c.delete());
}
```

Images: `CanvasKit.MakeImageFromEncoded(bytes)` (PNG/JPEG bytes). Read back with `surface.makeImageSnapshot().encodeToBytes()`.

## React Native Skia

Not tested in this repository's CI; a ready-made `<Transition>` component is planned (`@gl-transitions/react-native-skia`). With `@shopify/react-native-skia` the same file works as a runtime effect:

```tsx
import { Canvas, Fill, ImageShader, Shader, Skia, useImage } from "@shopify/react-native-skia";

const effect = Skia.RuntimeEffect.Make(sksl)!; // sksl: the file content, bundled as a string

function Transition({ from, to, progress, width, height, params }) {
  const rect = { x: 0, y: 0, width, height };
  return (
    <Canvas style={{ width, height }}>
      <Fill>
        <Shader
          source={effect}
          uniforms={{ _resolution: [width, height], progress, ratio: width / height, ...params }}
        >
          <ImageShader image={from} fit="cover" rect={rect} />
          <ImageShader image={to} fit="cover" rect={rect} />
        </Shader>
      </Fill>
    </Canvas>
  );
}
```

- `params` must contain every parameter (defaults from the catalog); pass `bool` parameters as 0 or 1.
- `progress` can be a Reanimated shared value or derived value to animate on the UI thread.
- Children order matters: `from`, `to`, then the extra textures.

## Other Skia hosts

skia-safe (Rust), Skia C++ (`SkRuntimeEffect::MakeForShader`), SkiaSharp (`SKRuntimeEffect.CreateShader`) and Compose Multiplatform (Skiko `RuntimeEffect`) take the same file with the same contract. Android's AGSL (`RuntimeShader`) is close but not identical and is not generated yet.
