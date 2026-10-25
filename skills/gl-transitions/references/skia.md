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
const loadSksl = (name) => fetch(`https://cdn.jsdelivr.net/npm/gl-transitions@2/sksl/${name}.sksl`).then((r) => r.text());
```

Then, in both:

```js
import CanvasKitInit from "canvaskit-wasm";
import transitions from "gl-transitions";

const CanvasKit = await CanvasKitInit();
const transition = transitions.find((t) => t.name === "Cube");
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

// extraImages: one image per transition.textures entry, in that order (e.g. the luma map of `LumaWipe`).
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

Use `@gl-transitions/react-native-skia`, whose README is at `https://github.com/gl-transitions/gl-transitions/tree/gl-transitions@<version>/packages/react-native-skia` (`<version>`: the one in the title of `catalog.md`) (React Native Skia 2, React 19; Reanimated only to animate `progress` without re-rendering):

```sh
npx expo install @shopify/react-native-skia react-native-reanimated
npm install gl-transitions @gl-transitions/react-native-skia
```

```tsx
import { Canvas } from "@shopify/react-native-skia";
import { Transition } from "@gl-transitions/react-native-skia";

<Canvas style={{ width: 360, height: 240 }}>
  <Transition name="CrossWarp" from={from} to={to} progress={progress} width={360} height={240} />
</Canvas>
```

- `from`, `to`: `SkImage` (`useImage(...)`, or the `currentFrame` of `useVideo(...)`), or shared values of them. While an image (or extra texture) is `null` nothing is drawn; a shared value still holding `null` is drawn as a transparent image instead.
- `progress`: a number or a Reanimated shared value.
- `params` (typed per transition; omitted ones keep their default), `textures` for extra images by name (`luma` for "LumaWipe", `displacementMap` for "DisplacementMap"), `fit` (default `"cover"`), `x`, `y`.

For your own children, `useTransitionEffect(name)` returns the compiled `effect` and `uniforms(width, height, progress, params?)`, a function that returns the uniforms object for a numeric `progress` (it is not a worklet: to animate with a shared value, call it once on the JS thread and override `progress` in `useDerivedValue(() => ({ ...base, progress: progress.value }))`, as `<Transition>` does). Children: `from`, `to`, then the extra textures, drawn at the output size and clamped. `getTransitionEffect(name)` is the same outside components.

```tsx
import { Fill, ImageShader, Shader } from "@shopify/react-native-skia";
import { useTransitionEffect } from "@gl-transitions/react-native-skia";

// Inside a <Canvas>; from, to: loaded SkImages, progress: a number.
function Wipe({ from, to, progress, width, height }) {
  const { effect, uniforms } = useTransitionEffect("Wind");
  const rect = { x: 0, y: 0, width, height };
  return (
    <Fill>
      <Shader source={effect} uniforms={uniforms(width, height, progress, { size: 0.4 })}>
        <ImageShader image={from} fit="cover" rect={rect} tx="clamp" ty="clamp" />
        <ImageShader image={to} fit="cover" rect={rect} tx="clamp" ty="clamp" />
      </Shader>
    </Fill>
  );
}
```

## Other Skia hosts

Skia C++ (`SkRuntimeEffect::MakeForShader`), SkiaSharp (`SKRuntimeEffect.CreateShader`) and Compose Multiplatform (Skiko `RuntimeEffect`) take the same file with the same contract. For skia-safe (Rust), the `gl-transitions` crate has the SkSL and packs its uniforms; on Android, the `com.gl-transitions:gl-transitions` library ships AGSL versions for `RuntimeShader` (see `native.md`).
