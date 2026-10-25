---
name: gl-transitions
description: Adds image and video transitions (fades, wipes, zooms, glitches, page curls...) from gl-transitions, an open collection of 125 GLSL shaders, with SkSL, GLSL ES 3.00, WGSL and Metal versions of those that translate (see compatibility.json). Use when the user wants a transition between two images, video clips, slides or scenes in WebGL, WebGPU, Skia (CanvasKit, React Native Skia), Remotion, editly, FFmpeg, Rust, Swift (Metal, AVFoundation) or Android, or names a gl-transition.
---

# gl-transitions

Each transition is a GLSL function `vec4 transition(vec2 uv)` that blends an outgoing image into an incoming one as `progress` goes from 0 to 1. The npm package `gl-transitions` ships every transition as GLSL, plus SkSL, GLSL ES 3.00, WGSL and Metal versions of each one that translates (`compatibility.json`), and a catalog (`gl-transitions.json`) with descriptions, tags and typed parameters. Ready-made packages wrap it for React Native Skia, Remotion, Rust, Swift and Android.

## 1. Pick a transition

Read `references/catalog.md` (by tag, then one line per transition). If it is missing, fetch `https://cdn.jsdelivr.net/npm/gl-transitions@2/skills/gl-transitions/references/catalog.md`.

- Match the user's words against descriptions and tags (`wipe`, `zoom`, `glitch`, `3d`...). Offer 2 or 3 candidates when the request is vague, with their preview link `https://gl-transitions.com/editor/<name>`.
- Prefer transitions without extra textures: `DisplacementMap` and `LumaWipe` need an additional image from the host.
- Names are PascalCase and case-sensitive (`CrossWarp`, `CrossZoom`, `Cube`). Version 2.0 renamed them: code written for 1.x (`crosswarp`, `cube`) needs the new names, listed in the package's CHANGELOG.md.

## 2. Get the source

| Need | Where |
|---|---|
| JS/TS project | `npm install gl-transitions`, then `import transitions from "gl-transitions"` and `transitions.find((t) => t.name === "Cube")` (`glsl`, `params`, `textures`; typed in `index.d.ts`) |
| GLSL file | `node_modules/gl-transitions/transitions/<name>.glsl` or `https://cdn.jsdelivr.net/npm/gl-transitions@2/transitions/<name>.glsl` |
| SkSL file | `node_modules/gl-transitions/sksl/<name>.sksl` or `https://cdn.jsdelivr.net/npm/gl-transitions@2/sksl/<name>.sksl` |
| GLSL ES 3.00, WGSL, Metal file | `glsl3/<name>.glsl`, `wgsl/<name>.wgsl`, `msl/<name>.metal` at the same places; uniform layouts in `layouts.json`, contracts in the package README |
| Which targets a transition supports | `compatibility.json` (a target a compiler rejected has no file) |

Pin the exact version (`gl-transitions@2.x.y`) in production URLs.

## 3. Wire it into the host

The host defines `progress`, `ratio`, `getFromColor(uv)`, `getToColor(uv)` and one uniform per parameter. **Always set every parameter**, to its `default` from the catalog unless the user chose a value: an unset uniform is 0 and breaks most transitions. Prefer a ready-made package when one fits the host: they set the parameters left out to their defaults.

| Host | Use | Read |
|---|---|---|
| WebGL / WebGL 2, regl, raw GLSL | The GLSL source with a small wrapper | `references/webgl.md` |
| React Native Skia | `@gl-transitions/react-native-skia`: `<Transition>` component | `references/skia.md` |
| CanvasKit (web, Node), other Skia | The shipped SkSL | `references/skia.md` |
| Remotion | `@gl-transitions/remotion`: `glTransition()` presentation for `<TransitionSeries>` | `references/video.md` |
| editly (Node video editing) | Built in | `references/video.md` |
| FFmpeg | The third-party `ffmpeg-gl-transition` filter (custom FFmpeg build) | `references/video.md` |
| WebGPU (three.js WebGPU, Babylon.js), wgpu, Bevy | The shipped WGSL; in Rust, the `gl-transitions` crate | `references/native.md` |
| Rust (skia-safe, wgpu, Bevy, fframes) | Crate `gl-transitions`: sources, typed parameters, packed uniforms | `references/native.md` |
| Swift: iOS, macOS, tvOS, visionOS (Metal, AVFoundation) | Swift package `GLTransitions` | `references/native.md` |
| Android 13+ (Views, Jetpack Compose) | `com.gl-transitions:gl-transitions` (AGSL `RuntimeShader`) | `references/native.md` |
| three.js (WebGL), PixiJS, Flutter, Unity, Godot | No dedicated package | Adapt the WebGL recipe where GLSL is accepted (three.js also takes `glsl3/` with `glslVersion: THREE.GLSL3`); otherwise port the GLSL |

## 4. Check the result

- At `progress = 0` the output must be the outgoing image, at `progress = 1` the incoming one (the specification; a few transitions are off by a pixel or a slight blur at the ends, e.g. `MosaicBlend`, `TangentMotionBlur`). Render both ends and one middle frame.
- An upside-down result means the image rows are flipped: `uv` has its origin at the bottom left (see each reference).
- A black or frozen result usually means a parameter was left unset or an extra texture is missing.
- Credit the author and license from the catalog when the user ships the result (most are MIT).
