# @gl-transitions/remotion

All of the [gl-transitions](https://gl-transitions.com) in [Remotion](https://www.remotion.dev): `glTransition()` makes any of them a presentation for `<TransitionSeries>`, between any two scenes.

It draws the GLSL source of each transition from the `gl-transitions` package with WebGL 2, as the GL Transition Specification describes it. New transitions arrive by updating `gl-transitions`.

## Install

```sh
npm install gl-transitions @gl-transitions/remotion @remotion/transitions
```

Requires Remotion 4.0.500 or later. The scenes are captured with Remotion's [HTML-in-canvas](https://www.remotion.dev/docs/html-in-canvas):

- **Rendering** (`npx remotion render`, the server-side APIs, Lambda) works out of the box: Remotion's browser has it enabled. For WebGL without a GPU, render with `--gl=swangle` (the default on Lambda); with one, `--gl=angle`.
- **The Studio** needs Chrome 149 or later with `chrome://flags/#canvas-draw-element` enabled. The preview can flash at the start of a transition, as with Remotion's own HTML-in-canvas presentations; rendered videos are not affected.

## Usage

```tsx
import { linearTiming, TransitionSeries } from "@remotion/transitions";
import { glTransition } from "@gl-transitions/remotion";

export const MyVideo = () => (
  <TransitionSeries>
    <TransitionSeries.Sequence durationInFrames={60}>
      <SceneA />
    </TransitionSeries.Sequence>
    <TransitionSeries.Transition
      presentation={glTransition({ name: "CrossWarp" })}
      timing={linearTiming({ durationInFrames: 30 })}
    />
    <TransitionSeries.Sequence durationInFrames={60}>
      <SceneB />
    </TransitionSeries.Sequence>
  </TransitionSeries>
);
```

Scenes can be any markup: images, videos, text, other compositions.

### Options

| Option     | Type   | Notes                                                                                                                                         |
| ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`     | string | Any transition name from [gl-transitions.com](https://gl-transitions.com); autocompletes                                                      |
| `params`   | object | The transition's parameters, typed per transition; the ones left out keep their default value                                                 |
| `textures` | object | Extra images a few transitions need, by name, as URLs: `luma` for "LumaWipe", `displacementMap` for "DisplacementMap". Rendering waits for them to load |

```tsx
glTransition({ name: "Cube", params: { persp: 0.7, unzoom: 0.3 } });
glTransition({ name: "LumaWipe", textures: { luma: staticFile("spiral.png") } });
```

Where a transition draws transparent pixels (LeftRight, TopBottom, the shadow of Bounce…), Remotion's output shows one of the captured scenes or black there, not the layers beneath `<TransitionSeries>`.

## Development

In the [gl-transitions repository](https://github.com/gl-transitions/gl-transitions), `examples/remotion` is a Remotion project using this package: `pnpm run studio` opens it, and `scripts/check.mjs` renders every transition with Remotion's renderer and compares it with its GLSL reference render, as the Reference renders workflow does on each pull request.
