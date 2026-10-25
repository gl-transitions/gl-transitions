---
"gl-transitions": major
"@gl-transitions/react-native-skia": minor
"@gl-transitions/remotion": minor
"gl-transitions-crate": minor
---

Transitions keep transparency. With transparent images (a layer to composite, a picture with an alpha channel), 29 transitions used to make pixels opaque, where a fill color was not even a parameter; none does now, and `validate-transition.mjs` checks it (README.md, "Transparency"). With opaque images, every transition renders the same colors as before.

- 13 transitions dropped the images' alpha (`HsvFade`, `FadeGrayscale`, `FlyEye`, `GlitchMemories`, `TangentMotionBlur`…) and now keep it.
- Where no image is drawn, transitions return transparent instead of opaque black: around the cube of `Cube`, beside the images of `Swap`, `Doorway`, `StereoViewer`, `LeftRight`, `TopBottom`, `SimpleFlip`, `RotateScaleVanish`, between the tiles of `LissajousTiles`. Where alpha is ignored (most video), that is the same black.
- Static noise (`TvStatic`, `StaticFade`, `StaticWipe`) covers the images, with their alpha. `Bounce`'s shadow darkens the incoming image instead of making it see-through, and is not cast where that image is transparent. `GlowDissolve` returns straight RGBA, like the images, instead of premultiplied.
- Fill colors can be transparent (they mix as straight RGBA, so a transparent color is best `vec4(0.0)`): `CircleIris`'s `backColor`, `FadeColor`'s `color` and `UndulatingBurnOut`'s `color` are now `vec4` (add an alpha of 1 to the values you pass; the Swift, Android and Rust packages reject a `vec3`).

Thanks to @bradedelman, whose #203 raised the problem.
