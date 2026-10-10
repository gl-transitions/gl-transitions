# Video tools

## editly (works today)

[editly](https://github.com/mifi/editly) depends on `gl-transitions` and accepts any transition name between clips:

```js
import editly from "editly";

await editly({
  outPath: "out.mp4",
  defaults: { transition: { name: "crosswarp", duration: 0.5 } },
  clips: [
    { layers: [{ type: "video", path: "a.mp4" }] },
    { transition: { name: "cube", duration: 1, params: { persp: 0.5 } }, layers: [{ type: "image", path: "b.jpg" }] },
  ],
});
```

- `transition` on a clip applies between that clip and the next one.
- `params` sets transition parameters (undocumented in editly but supported); omitted ones keep their defaults.
- Also `random`, `dummy` (none), and `directional-left|right|up|down`.

## FFmpeg (third-party filter)

FFmpeg has no gl-transitions support of its own (its `xfade` filter has a separate, fixed set). The [`ffmpeg-gl-transition`](https://github.com/transitive-bullshit/ffmpeg-gl-transition) filter runs a `.glsl` file, but it needs FFmpeg rebuilt with the filter and an OpenGL context (GLFW or EGL for headless servers):

```sh
ffmpeg -i a.mp4 -i b.mp4 -filter_complex "gltransition=duration=1:offset=2:source=crosswarp.glsl" -y out.mp4
```

The filter sets `progress` and `ratio` but **no parameters**: their uniforms stay 0. For a transition with parameters, bake the values in before writing the `.glsl` file, turning each parameter uniform into a constant:

```js
import transitions from "gl-transitions";

// "uniform float persp; // = 0.7" -> "const float persp = 0.7;" (user values, else defaults)
function bakeParams(transition, values = {}) {
  const float = (v) => (Number.isInteger(v) ? v.toFixed(1) : String(v)); // GLSL ES 1.00 needs "1.0", not "1"
  const literal = (type, v) =>
    Array.isArray(v) ? `${type}(${v.join(", ")})` : type === "float" ? float(Number(v)) : String(v);
  let glsl = transition.glsl;
  for (const [name, p] of Object.entries(transition.params)) {
    // Remove the name from its uniform declaration (it may declare several names, and /* = default */ comments).
    glsl = glsl.replace(new RegExp(`uniform\\s+${p.type}\\s+([^;]*);`, "g"), (decl, names) => {
      const rest = names
        .replace(/\/\*[\s\S]*?\*\//g, "")
        .split(",")
        .map((n) => n.trim())
        .filter((n) => n !== name);
      return rest.length ? `uniform ${p.type} ${rest.join(", ")};` : "";
    });
    glsl = `const ${p.type} ${name} = ${literal(p.type, values[name] ?? p.default)};\n` + glsl;
  }
  return glsl;
}
```

The constants go at the top of the file, so they are defined before any function uses them. Transitions with extra textures (`displacement`, `luma`) do not work with this filter.

Without a custom FFmpeg build, render the transition frames yourself (WebGL in headless Chrome with `references/webgl.md`, or CanvasKit in Node with `references/skia.md`) and encode them with FFmpeg, or use editly, which does exactly that.

## Remotion (planned)

There is no gl-transitions presentation for `@remotion/transitions` yet (a `@gl-transitions/remotion` package is planned). For images and videos, a component can do it today:

- render a `<canvas>` and draw with the WebGL recipe from `references/webgl.md`;
- compute `progress` from `useCurrentFrame()` (e.g. `interpolate(frame, [start, start + duration], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp" })`);
- load images with `delayRender` / `continueRender` so frames are not captured before textures are ready, and pass `preserveDrawingBuffer: true` to `getContext("webgl")`.

Transitions between arbitrary React scenes are not possible this way: the scenes would have to be rasterized first.
