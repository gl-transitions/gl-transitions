# GL Transitions

[![CI](https://github.com/gl-transitions/gl-transitions/actions/workflows/ci.yml/badge.svg)](https://github.com/gl-transitions/gl-transitions/actions/workflows/ci.yml)
[![npm](https://img.shields.io/npm/v/gl-transitions)](https://www.npmjs.com/package/gl-transitions)
[![crates.io](https://img.shields.io/crates/v/gl-transitions)](https://crates.io/crates/gl-transitions)
[![Maven Central](https://img.shields.io/maven-central/v/com.gl-transitions/gl-transitions)](https://central.sonatype.com/artifact/com.gl-transitions/gl-transitions)

<a href="https://gl-transitions.com/gallery"><img src=".github/readme/transitions.webp" width="800" alt="Twelve transitions playing between sample images: cube, doorway, crosswarp, ripple, Swirl, BookFlip, GlitchMemories, windowslice, InvertedPageCurl, pixelize, morph and wind"></a>

An open collection of 100+ transitions between two images, written by the community as small GLSL functions that follow one [specification](#gl-transition-specification-v1). They are translated to SkSL, GLSL ES 3.00, WGSL, Metal and AGSL, for web pages, React Native and Android apps, iOS and macOS video exports or Rust renderers. CI compiles every translation, renders the SkSL, WGSL, Metal and AGSL ones and compares them with the GLSL original, and `compatibility.json` in the npm package gives the result for each transition and target.

**Browse them and edit them live at [gl-transitions.com](https://gl-transitions.com).**

## Use the transitions

| Platform | Package | Install |
|---|---|---|
| Any JavaScript: the sources in every language, with their parameters | [`gl-transitions`](packages/gl-transitions) | `npm install gl-transitions` |
| WebGL, regl, gl-react, rendering videos from the command line | [`gl-transition`, `regl-transition`, `react-gl-transition`, `gl-transition-scripts`](https://github.com/gre/gl-transition-libs) | `npm install gl-transition` (or `regl-transition`, `react-gl-transition`, `gl-transition-scripts`) |
| React Native Skia | [`@gl-transitions/react-native-skia`](packages/react-native-skia) | `npm install gl-transitions @gl-transitions/react-native-skia`, with `@shopify/react-native-skia` |
| Remotion | [`@gl-transitions/remotion`](packages/remotion) | `npm install gl-transitions @gl-transitions/remotion @remotion/transitions` |
| Apple platforms: Metal, AVFoundation video compositions, SwiftUI | [`GLTransitions`](swift) | Swift Package Manager, from [gl-transitions-swift](https://github.com/gl-transitions/gl-transitions-swift) |
| Android 13+: AGSL `RuntimeShader`, Kotlin and Java | [`com.gl-transitions:gl-transitions`](android) | Gradle, from Maven Central |
| Rust: skia-safe, wgpu, Bevy… | [`gl-transitions`](crates/gl-transitions) | `cargo add gl-transitions` |
| Coding agents | [llms.txt](https://cdn.jsdelivr.net/npm/gl-transitions@1/llms.txt), [Agent Skill](skills/gl-transitions/SKILL.md) | |

Each package's README has a usage example. Example apps: [SwiftUI](examples/swiftui), [Android](examples/android), [React Native Skia](examples/react-native-skia), [Remotion](examples/remotion), [fframes](examples/fframes).

Outside this project, the transitions are also used by [editly](https://github.com/mifi/editly), [ffmpeg-gl-transition](https://github.com/transitive-bullshit/ffmpeg-gl-transition) and [xfade-easing](https://github.com/scriptituk/xfade-easing) (FFmpeg).

## Contribute a transition

1. Write it in the [editor](https://gl-transitions.com/editor), which renders it as you type.
2. Open a pull request that adds `transitions/YourTransition.glsl`, following the [specification](#gl-transition-specification-v1) and [CONTRIBUTING.md](CONTRIBUTING.md).
3. CI checks it, renders it and comments preview GIFs on the pull request.

## Releases

New transitions merged into master are published in the next minor release of the npm package, listed in the [changelog](packages/gl-transitions/CHANGELOG.md). The Swift package and the Android library are released with the same version, and the Rust crate with a patch release ([changelog](crates/gl-transitions/CHANGELOG.md)).

## License

[MIT](LICENSE). Each transition states its license in its header, and the packages give it with each transition: all are MIT except two under BSD licenses.

# GL Transition Specification v1

**NB. This is a technical documentation, for more informal information, please see the [gl-transitions.com](https://gl-transitions.com/) homepage.**

This document specifies GL Transition Specification **v1**, `1` as in `gl-transitions @ 1` (consistently to the NPM package major). For any breaking changes in this specification, semver will be respected and the major will get bumped.

## What is a transition?

A Transition is an animation that smoothly animates the intermediary steps between 2 textures: `from` and `to`. The step is specified by a `progress` value that moves from `0.0` to `1.0`.

> important feature to respect: When progress is 0.0, exclusively the `from` texture must be rendered. When progress is 1.0, exclusively the `to` texture must be rendered.

## GL Transition

```glsl
// transition of a simple fade.
vec4 transition (vec2 uv) {
  return mix(
    getFromColor(uv),
    getToColor(uv),
    progress
  );
}
```

A GL Transition is a GLSL code that implements a `transition` function which takes a `vec2 uv` pixel position and returns a `vec4` color. This color represents the mix of the `from` to the `to` textures based on the variation of a contextual `progress` value from `0.0` to `1.0`.

### Contextual variables

- `progress` (float): a value that **moves from 0.0 to 1.0** during the transition.
- `ratio` (float): the ratio of the viewport. It equals `width / height`. *(width and height are not exposed because you don't need them. A transition code should be scalable to any size. ratio can still be used to preserve some shape ratio, e.g. you want to draw squares)*

### Contextual functions

- `vec4 getFromColor(vec2 uv)`: lookup the "from" texture at a given uv coordinate.
- `vec4 getToColor(vec2 uv)`: lookup the "to" texture at a given uv coordinate.

> don't directly use `texture2D` to get a texture pixel out of the from and to textures. Instead, use `getFromColor(vec2)` and `getToColor(vec2)`. That way, the "implementer" can properly implement ratio preserving support as well as choosing a different color for the "out of bound" case.

### Transition parameters

Transition parameters are parameters that the final user can set to tweak the transition. They are constant over a full run of a transition *(no parameter changes when progress moves from 0.0 to 1.0)*.

> any constant you define in your transitions are potential parameters to expose.

When you define a transition parameter, you must also define a default value that will get set in case the final user didn't provide it. It's unfortunately not possible to initialize a uniform in GLSL ES 1.00 (WebGL 1) but we support commented code `// = value`

Examples:

```glsl
uniform float foo; // = 42.0
uniform vec2 foo; // = vec2(42.0, 42.0)
```

The following variants are also supported:

```glsl
uniform float foo/* = 42.0 */;
uniform vec2 foo /*= vec2(42.0, 42.0)*/, bar /* = vec2(1.) */;
uniform vec2 foo, bar; // = vec2(1.0, 2.0); // both at the same time ! (needs a ';' if you have this second //, like usual glsl code)
```

### Transition metadata (optional)

Transitions can describe themselves so that tools, editors and package integrations can list, search and expose them with a proper UI. All of it is optional and lives in comments, so the shader stays valid GLSL.

Header lines, next to `Author` and `License`:

```glsl
// Author: Adrian Purser
// License: MIT
// Description: The outgoing image drops out of the frame with a few bounces, revealing the incoming one
// Tags: bounce, slide, vertical, shadow
```

- `Description`: one line describing what the transition looks like.
- `Tags`: comma-separated, lowercase words or dash-separated words (e.g. `wipe`, `zoom-in`).

Parameter hints go on comment lines **directly above** the uniform they describe. Text after the hints is the parameter description; `@param` alone marks a description-only line:

```glsl
// @color Color of the shadow cast on the incoming image
uniform vec4 shadow_colour; // = vec4(0.,0.,0.,.6)
// @range(1, 10, 1) Number of bounces before settling
uniform float bounces; // = 3.0
// @param Wipe from right to left instead
uniform bool reversed; // = false
```

| Hint | Applies to | Meaning |
|---|---|---|
| `@range(min, max)` / `@range(min, max, step)` | `float`, `int`, `vec*`, `ivec*` | Suggested bounds for a UI control (applies per component for vectors) |
| `@color` | `vec3`, `vec4` | The value is an RGB / RGBA color |
| `@param` | any | No hint, only a description |

Hints are on their own line (not after the default value) so that existing parsers of the `// = value` syntax keep working.

### Extra textures

A transition may declare additional `uniform sampler2D` inputs (e.g. `luma`, `displacement`). They are listed in the `textures` field of `gl-transitions.json`; the implementer is responsible for providing them. They are sampled with `texture2D` directly (e.g. `texture2D(luma, uv)`).

### `gl-transitions.json` format

The npm package exposes the collection as an array of objects:

| Field | Description |
|---|---|
| `name` | File name without `.glsl`. Stable: never renamed once published |
| `author`, `license` | From the header comments |
| `glsl` | The transition source |
| `paramsTypes`, `defaultParams` | Parameter types and default values (legacy, kept for compatibility) |
| `params` | Per parameter: `type`, `default`, and when annotated `min`, `max`, `step`, `color`, `description` |
| `description`, `tags` | From the header comments (`tags` is always an array) |
| `textures` | Extra `sampler2D` inputs beyond `from` and `to` |
| `createdAt`, `updatedAt` | From git history |


# `gl-transitions` collection policy

- If we have duplicated transitions or one transition is more generic than another one, we don't necessarily drop the less generic one: it might be more performant and might fit for some users. We also want to keep backward compat'. If we still want to drop it, what we will do is to deprecate it and drop it at the next major bump.
