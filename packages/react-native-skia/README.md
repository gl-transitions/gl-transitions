# @gl-transitions/react-native-skia

All of the [gl-transitions](https://gl-transitions.com) in [React Native Skia](https://shopify.github.io/react-native-skia/): a `<Transition>` component that draws any of them between two images, or two video frames, inside a Skia `<Canvas>`.

It uses the SkSL version of each transition shipped in the `gl-transitions` package, which CI compiles with Skia and compares against the GLSL original. New transitions arrive by updating `gl-transitions`.

## Install

```sh
npx expo install @shopify/react-native-skia react-native-reanimated
npm install gl-transitions @gl-transitions/react-native-skia
```

Requires React Native Skia 2 and React 19. Reanimated is only needed to animate `progress` without re-rendering.

## Usage

```tsx
import { Canvas, useImage } from "@shopify/react-native-skia";
import { useEffect } from "react";
import { useSharedValue, withRepeat, withTiming } from "react-native-reanimated";
import { Transition } from "@gl-transitions/react-native-skia";

export default function App() {
  const from = useImage(require("./assets/a.jpg"));
  const to = useImage(require("./assets/b.jpg"));
  const progress = useSharedValue(0);
  useEffect(() => {
    progress.value = withRepeat(withTiming(1, { duration: 1500 }), -1, true);
  }, [progress]);

  return (
    <Canvas style={{ width: 360, height: 240 }}>
      <Transition name="crosswarp" from={from} to={to} progress={progress} width={360} height={240} />
    </Canvas>
  );
}
```

Nothing is drawn until both images are loaded.

### Props

| Prop              | Type                                       | Notes                                                                                                 |
| ----------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------------------- |
| `name`            | string                                     | Any transition name from [gl-transitions.com](https://gl-transitions.com); autocompletes              |
| `from`, `to`      | `SkImage \| null`, or a shared value of it | e.g. `useImage(…)`, or the `currentFrame` of `useVideo(…)` for video                                  |
| `progress`        | `number`, or a shared value                | 0 shows `from`, 1 shows `to`                                                                          |
| `width`, `height` | number                                     | Size of the drawn rectangle                                                                           |
| `x`, `y`          | number                                     | Position, default 0                                                                                   |
| `params`          | object                                     | The transition's parameters, typed per transition; the ones left out keep their default value         |
| `textures`        | object                                     | Extra images a few transitions need, by name: `luma` for "luma", `displacementMap` for "displacement" |
| `fit`             | `Fit`                                      | How images fill the rectangle, default `"cover"`                                                      |

```tsx
<Transition name="GridFlip" params={{ size: [6, 4], pause: 0.2 }} {...rest} />
<Transition name="luma" textures={{ luma: useImage(require("./assets/spiral.png")) }} {...rest} />
```

### Your own children

`useTransitionEffect(name)` returns the compiled effect and a uniforms builder, to use with `<Shader>` and any children: the first two are `from` and `to`, then one per entry of `transition.textures`. Children are sampled in the shader's pixel coordinates, so draw them at the output size.

```tsx
import { Fill, ImageShader, Shader } from "@shopify/react-native-skia";
import { useTransitionEffect } from "@gl-transitions/react-native-skia";

function Wipe({ from, to, progress, width, height }) {
  const { effect, uniforms } = useTransitionEffect("wind");
  const rect = { x: 0, y: 0, width, height };
  return (
    <Fill>
      <Shader source={effect} uniforms={uniforms(width, height, progress, { size: 0.4 })}>
        <ImageShader image={from} fit="cover" rect={rect} />
        <ImageShader image={to} fit="cover" rect={rect} />
      </Shader>
    </Fill>
  );
}
```

`getTransitionEffect(name)` is the same outside of components, for example to render offscreen.

## Development

In the [gl-transitions repository](https://github.com/gl-transitions/gl-transitions), from the root:

```sh
npm install
npm test        # builds this package, then renders every transition with React Native Skia's headless (CanvasKit) build
```

The Reference renders workflow also compares every transition rendered through this package with its GLSL reference.

The repository replaces React Native Skia's prebuilt native binaries (about 750 MB) with an empty package, see `overrides` in its root `package.json`: tests only use the headless build.
