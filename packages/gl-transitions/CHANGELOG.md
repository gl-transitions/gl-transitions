# gl-transitions

## 2.0.0

### Major Changes

- [#336](https://github.com/gl-transitions/gl-transitions/pull/336) [`bd4ee21`](https://github.com/gl-transitions/gl-transitions/commit/bd4ee21d57c1f09ec99bf6e4af50ebffbcf52ca2) Thanks [@gre](https://github.com/gre)! - gl-transitions 2.0 renames the transitions and makes them keep transparency. Every package takes the new names: update the names your code uses, with the tables below. The Swift package and the Android library follow the version of the npm package.

  **Names.** Every transition has a PascalCase name, checked by the lint along with the other naming rules (CONTRIBUTING.md, "Naming"): 45 names only change case, 34 get a clearer name. Two near-duplicates are removed: `CircleCrop` (the closest is `CircleIris`, an ellipse over a dark gray `backColor`) and `PuzzleRight` (the closest is `GridFlip`, with thicker dividers and a random order).

  **Transparency.** With transparent images (a layer to composite, a picture with an alpha channel), 29 transitions made pixels opaque; none does now, and `validate-transition.mjs` checks it (README.md, "Transparency"). With opaque images, every transition renders the same colors as before.

  - 13 transitions dropped the images' alpha (`HsvFade`, `FadeGrayscale`, `FlyEye`, `GlitchMemories`, `TangentMotionBlur`…) and now keep it; `GlowDissolve` returns straight RGBA instead of premultiplied.
  - Where no image is drawn, transitions return transparent instead of opaque black: `Cube`, `Swap`, `Doorway`, `StereoViewer`, `LeftRight`, `TopBottom`, `SimpleFlip`, `RotateScaleVanish`, `LissajousTiles`. Where alpha is ignored (most video), that is the same black.
  - Static noise (`TvStatic`, `StaticFade`, `StaticWipe`) covers the images, with their alpha. `Bounce`'s shadow darkens the incoming image instead of making it see-through.
  - `CircleIris`'s `backColor`, `FadeColor`'s `color` and `UndulatingBurnOut`'s `color` are now `vec4`, so they can be transparent: add an alpha of 1 to the values you pass (the Swift, Android and Rust packages reject a `vec3`).

  Thanks to @bradedelman, whose [#203](https://github.com/gl-transitions/gl-transitions/issues/203) raised the transparency problem.

  Renamed:

  | 1.x                    | 2.0                |
  | ---------------------- | ------------------ |
  | `AdvancedMosaic`       | `MosaicBlend`      |
  | `angular`              | `ClockWipe`        |
  | `BowTieWithParameter`  | `BowTie`           |
  | `burn`                 | `FlashFade`        |
  | `burn0`                | `BurnThrough`      |
  | `cannabisleaf`         | `LeafWipe`         |
  | `circle`               | `CircleIris`       |
  | `ColourDistance`       | `ColorDistance`    |
  | `coord-from-in`        | `ColorCoords`      |
  | `directional-easing`   | `DirectionalEased` |
  | `displacement`         | `DisplacementMap`  |
  | `dissolve`             | `GlowDissolve`     |
  | `DoomScreenTransition` | `DoomMelt`         |
  | `Drop_Zone_Flicker`    | `GlitchFlicker`    |
  | `EdgeTransition`       | `EdgeGlow`         |
  | `fragment`             | `Shatter`          |
  | `heart`                | `HeartWipe`        |
  | `luma`                 | `LumaWipe`         |
  | `mosaic_transition`    | `MosaicFade`       |
  | `old_tv_lost_signal`   | `TvLostSignal`     |
  | `parametric_glitch`    | `GlitchBands`      |
  | `perlin`               | `PerlinDissolve`   |
  | `polar_function`       | `FlowerWipe`       |
  | `Radial`               | `RadialWipe`       |
  | `randomNoisex`         | `NoiseDissolve`    |
  | `Rectangle`            | `RectangleCover`   |
  | `RectangleCrop`        | `RectangleIris`    |
  | `Revolve_Left`         | `Revolve`          |
  | `rotateTransition`     | `RotateFade`       |
  | `squareswire`          | `SquaresWipe`      |
  | `windowslice`          | `WindowSlices`     |
  | `x_axis_translation`   | `SlideAwayRight`   |
  | `ZoomLeftWipe`         | `ZoomWipeLeft`     |
  | `ZoomRigthWipe`        | `ZoomWipeRight`    |

  Case only:

  | 1.x                         | 2.0                         |
  | --------------------------- | --------------------------- |
  | `chessboard`                | `Chessboard`                |
  | `circleopen`                | `CircleOpen`                |
  | `colorphase`                | `ColorPhase`                |
  | `crosshatch`                | `Crosshatch`                |
  | `crosswarp`                 | `CrossWarp`                 |
  | `cube`                      | `Cube`                      |
  | `directionalwarp`           | `DirectionalWarp`           |
  | `directionalwipe`           | `DirectionalWipe`           |
  | `doorway`                   | `Doorway`                   |
  | `fade`                      | `Fade`                      |
  | `fadecolor`                 | `FadeColor`                 |
  | `fadegrayscale`             | `FadeGrayscale`             |
  | `flyeye`                    | `FlyEye`                    |
  | `hexagonalize`              | `Hexagonalize`              |
  | `HSVfade`                   | `HsvFade`                   |
  | `kaleidoscope`              | `Kaleidoscope`              |
  | `luminance_melt`            | `LuminanceMelt`             |
  | `morph`                     | `Morph`                     |
  | `multiply_blend`            | `MultiplyBlend`             |
  | `pinwheel`                  | `Pinwheel`                  |
  | `pixelize`                  | `Pixelize`                  |
  | `powerKaleido`              | `PowerKaleido`              |
  | `randomsquares`             | `RandomSquares`             |
  | `ripple`                    | `Ripple`                    |
  | `rotate_scale_fade`         | `RotateScaleFade`           |
  | `scale-in`                  | `ScaleIn`                   |
  | `splitSlideInHorizontal`    | `SplitSlideInHorizontal`    |
  | `splitSlideInOutHorizontal` | `SplitSlideInOutHorizontal` |
  | `splitSlideInOutVertical`   | `SplitSlideInOutVertical`   |
  | `splitSlideInVertical`      | `SplitSlideInVertical`      |
  | `splitSlideOutHorizontal`   | `SplitSlideOutHorizontal`   |
  | `splitSlideOutVertical`     | `SplitSlideOutVertical`     |
  | `squeeze`                   | `Squeeze`                   |
  | `static_wipe`               | `StaticWipe`                |
  | `swap`                      | `Swap`                      |
  | `tangentMotionBlur`         | `TangentMotionBlur`         |
  | `TVStatic`                  | `TvStatic`                  |
  | `undulatingBurnOut`         | `UndulatingBurnOut`         |
  | `wind`                      | `Wind`                      |
  | `windowblinds`              | `WindowBlinds`              |
  | `wipeDown`                  | `WipeDown`                  |
  | `wipeLeft`                  | `WipeLeft`                  |
  | `wipeRight`                 | `WipeRight`                 |
  | `wipeUp`                    | `WipeUp`                    |
  | `zoomInOut`                 | `ZoomInOut`                 |

### Minor Changes

- [#334](https://github.com/gl-transitions/gl-transitions/pull/334) [`b014364`](https://github.com/gl-transitions/gl-transitions/commit/b0143643626bd8d9c2377fbadba05654acf6f1fc) Thanks [@gre](https://github.com/gre)! - New transition: `ColorWrap` by Yoni Maltsman @friendlyspinach.

- [#335](https://github.com/gl-transitions/gl-transitions/pull/335) [`03a0fef`](https://github.com/gl-transitions/gl-transitions/commit/03a0fef153761c9c38de53dd68c2ae7e2c5c2d2e) Thanks [@gre](https://github.com/gre)! - New transition: `LissajousTiles` by Boundless <info@boundless-beta.com>.

- [#336](https://github.com/gl-transitions/gl-transitions/pull/336) [`bd4ee21`](https://github.com/gl-transitions/gl-transitions/commit/bd4ee21d57c1f09ec99bf6e4af50ebffbcf52ca2) Thanks [@gre](https://github.com/gre)! - Removed `CircleCrop`, `PuzzleRight`.

- [#340](https://github.com/gl-transitions/gl-transitions/pull/340) [`86abf0d`](https://github.com/gl-transitions/gl-transitions/commit/86abf0daa414f38e9c1601bc1655737d4fa62173) Thanks [@gre](https://github.com/gre)! - Updated 29 transitions.

- [#336](https://github.com/gl-transitions/gl-transitions/pull/336) [`bd4ee21`](https://github.com/gl-transitions/gl-transitions/commit/bd4ee21d57c1f09ec99bf6e4af50ebffbcf52ca2) Thanks [@gre](https://github.com/gre)! - Updated `LeafWipe`.

### Patch Changes

- [#329](https://github.com/gl-transitions/gl-transitions/pull/329) [`7dcf5a8`](https://github.com/gl-transitions/gl-transitions/commit/7dcf5a88d690994cda017b35a8bce70167b958dd) Thanks [@gre](https://github.com/gre)! - The Agent Skill and llms.txt now cover every target and package: GLSL ES 3.00, WGSL and Metal files, `@gl-transitions/react-native-skia`, `@gl-transitions/remotion`, the Rust crate, the Swift package and the Android library (new `references/native.md`).

## 1.76.1

### Patch Changes

- [#292](https://github.com/gl-transitions/gl-transitions/pull/292) [`3acb1e4`](https://github.com/gl-transitions/gl-transitions/commit/3acb1e43cf88ff72fe01337e0f3b8d61659f6e30) Thanks [@gre](https://github.com/gre)! - The package ships its CHANGELOG.md: releases are now prepared with changesets, and each transition added or changed is listed.
