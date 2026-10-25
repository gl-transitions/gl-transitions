# Remotion example

A Remotion project using [`@gl-transitions/remotion`](../../packages/remotion) from this repository, with the `gl-transitions` package built from it.

- **Showcase**: a few transitions between React scenes (CrossWarp, Cube, LumaWipe with a spiral texture, Dreamy), over an animated shader background (`src/Backdrop.tsx`: domain-warped noise with glowing contour lines and film grain).
- **Check**: every transition in turn between the images of the GLSL reference renders. `scripts/check.mjs` renders it and compares each transition with its reference (the Reference renders workflow runs it on pull requests).

## Run it

```sh
# From the repository root: build gl-transitions and the package (their dist/)
pnpm install && pnpm run build && pnpm --filter @gl-transitions/remotion run build

cd examples/remotion
pnpm run studio        # needs Chrome 149+ with chrome://flags/#canvas-draw-element enabled
pnpm run prepare-images && pnpm exec remotion render src/index.ts Showcase out/showcase.mp4 --gl=angle

# Compare with GLSL reference renders (pnpm run render:references --out /tmp/refs, from the root)
pnpm run check /tmp/refs --renders /tmp/remotion-renders
```
