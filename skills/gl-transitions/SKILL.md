---
name: gl-transitions
description: Adds image and video transitions (fades, wipes, zooms, glitches, page curls...) from gl-transitions, an open collection of 125 GLSL shaders also compiled to SkSL. Use when the user wants a transition between two images, video clips, slides or scenes in WebGL, Skia (CanvasKit, React Native Skia), FFmpeg or editly, or names a gl-transition.
---

# gl-transitions

Each transition is a GLSL function `vec4 transition(vec2 uv)` that blends an outgoing image into an incoming one as `progress` goes from 0 to 1. The npm package `gl-transitions` ships every transition as GLSL, as SkSL, and as a catalog (`gl-transitions.json`) with descriptions, tags and typed parameters.

## 1. Pick a transition

Read `references/catalog.md` (by tag, then one line per transition). If it is missing, fetch `https://cdn.jsdelivr.net/npm/gl-transitions@1/skills/gl-transitions/references/catalog.md`.

- Match the user's words against descriptions and tags (`wipe`, `zoom`, `glitch`, `3d`...). Offer 2 or 3 candidates when the request is vague, with their preview link `https://gl-transitions.com/editor/<name>`.
- Prefer transitions without extra textures: `displacement` and `luma` need an additional image from the host.
- Names are case-sensitive and stable (`crosswarp`, `CrossZoom`, `cube`).

## 2. Get the source

| Need | Where |
|---|---|
| JS/TS project | `npm install gl-transitions`, then `import transitions from "gl-transitions"` and `transitions.find((t) => t.name === "cube")` (`glsl`, `params`, `textures`; typed in `index.d.ts`) |
| GLSL file | `node_modules/gl-transitions/transitions/<name>.glsl` or `https://cdn.jsdelivr.net/npm/gl-transitions@1/transitions/<name>.glsl` |
| SkSL file | `node_modules/gl-transitions/sksl/<name>.sksl` or `https://cdn.jsdelivr.net/npm/gl-transitions@1/sksl/<name>.sksl` |

Pin the exact version (`gl-transitions@1.x.y`) in production URLs.

## 3. Wire it into the host

The host defines `progress`, `ratio`, `getFromColor(uv)`, `getToColor(uv)` and one uniform per parameter. **Always set every parameter**, to its `default` from the catalog unless the user chose a value: an unset uniform is 0 and breaks most transitions.

| Host | Status | Read |
|---|---|---|
| WebGL / WebGL 2, regl, raw GLSL | Works today | `references/webgl.md` |
| CanvasKit (web, Node), React Native Skia, other Skia | Works today with the shipped SkSL | `references/skia.md` |
| editly (Node video editing) | Works today: built in | `references/video.md` |
| FFmpeg | Works with the third-party `ffmpeg-gl-transition` filter (custom FFmpeg build) | `references/video.md` |
| Remotion | No adapter yet (planned: `@gl-transitions/remotion`); possible for images and videos with the WebGL recipe | `references/video.md` |
| three.js, PixiJS, WGSL/WebGPU, Metal, Android, Flutter, Unity, Godot | Planned, not available yet | Use the WebGL recipe where GLSL is accepted |

## 4. Check the result

- At `progress = 0` the output must be exactly the outgoing image, at `progress = 1` exactly the incoming one. Render both ends and one middle frame.
- An upside-down result means the image rows are flipped: `uv` has its origin at the bottom left (see each reference).
- A black or frozen result usually means a parameter was left unset or an extra texture is missing.
- Credit the author and license from the catalog when the user ships the result (most are MIT).
