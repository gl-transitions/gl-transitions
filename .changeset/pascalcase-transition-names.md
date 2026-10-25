---
"gl-transitions": major
"@gl-transitions/react-native-skia": minor
"@gl-transitions/remotion": minor
"gl-transitions-crate": minor
---

Every transition now has a PascalCase name, checked by the lint and CI along with the other naming rules (CONTRIBUTING.md, "Naming"). 45 names only change case, 34 get a clearer name, and two near-duplicates are removed. The renamed transitions render as before, with the same parameters (but see the transparency changes of this release: three fill colors became a `vec4`).

`renamed.json`, in the npm package, maps each 1.x name to its new name, for names stored in projects or settings: `Object.hasOwn(renamed, name) ? renamed[name] : name`. The React Native Skia and Remotion packages and the Rust crate take the new names (and `gl-transitions` 2.0); the Swift package and the Android library follow the npm package version.

Removed near-duplicates, mapped to the closest transition (which looks alike, but is not the same):

| 1.x | Use instead | Differences |
|---|---|---|
| `CircleCrop` | `CircleIris` | An ellipse that follows the image's shape instead of a circle; a dark gray `backColor` instead of a black `bgcolor`; a `center` parameter |
| `PuzzleRight` | `GridFlip` | Thicker dividers by default (`dividerWidth`), a `bgcolor`, tiles flipping in a random order (`randomness`) |

Renamed:

| 1.x | 2.0 |
|---|---|
| `AdvancedMosaic` | `MosaicBlend` |
| `angular` | `ClockWipe` |
| `BowTieWithParameter` | `BowTie` |
| `burn` | `FlashFade` |
| `burn0` | `BurnThrough` |
| `cannabisleaf` | `LeafWipe` |
| `circle` | `CircleIris` |
| `ColourDistance` | `ColorDistance` |
| `coord-from-in` | `ColorCoords` |
| `directional-easing` | `DirectionalEased` |
| `displacement` | `DisplacementMap` |
| `dissolve` | `GlowDissolve` |
| `DoomScreenTransition` | `DoomMelt` |
| `Drop_Zone_Flicker` | `GlitchFlicker` |
| `EdgeTransition` | `EdgeGlow` |
| `fragment` | `Shatter` |
| `heart` | `HeartWipe` |
| `luma` | `LumaWipe` |
| `mosaic_transition` | `MosaicFade` |
| `old_tv_lost_signal` | `TvLostSignal` |
| `parametric_glitch` | `GlitchBands` |
| `perlin` | `PerlinDissolve` |
| `polar_function` | `FlowerWipe` |
| `Radial` | `RadialWipe` |
| `randomNoisex` | `NoiseDissolve` |
| `Rectangle` | `RectangleCover` |
| `RectangleCrop` | `RectangleIris` |
| `Revolve_Left` | `Revolve` |
| `rotateTransition` | `RotateFade` |
| `squareswire` | `SquaresWipe` |
| `windowslice` | `WindowSlices` |
| `x_axis_translation` | `SlideAwayRight` |
| `ZoomLeftWipe` | `ZoomWipeLeft` |
| `ZoomRigthWipe` | `ZoomWipeRight` |

Case only:

| 1.x | 2.0 |
|---|---|
| `chessboard` | `Chessboard` |
| `circleopen` | `CircleOpen` |
| `colorphase` | `ColorPhase` |
| `crosshatch` | `Crosshatch` |
| `crosswarp` | `CrossWarp` |
| `cube` | `Cube` |
| `directionalwarp` | `DirectionalWarp` |
| `directionalwipe` | `DirectionalWipe` |
| `doorway` | `Doorway` |
| `fade` | `Fade` |
| `fadecolor` | `FadeColor` |
| `fadegrayscale` | `FadeGrayscale` |
| `flyeye` | `FlyEye` |
| `hexagonalize` | `Hexagonalize` |
| `HSVfade` | `HsvFade` |
| `kaleidoscope` | `Kaleidoscope` |
| `luminance_melt` | `LuminanceMelt` |
| `morph` | `Morph` |
| `multiply_blend` | `MultiplyBlend` |
| `pinwheel` | `Pinwheel` |
| `pixelize` | `Pixelize` |
| `powerKaleido` | `PowerKaleido` |
| `randomsquares` | `RandomSquares` |
| `ripple` | `Ripple` |
| `rotate_scale_fade` | `RotateScaleFade` |
| `scale-in` | `ScaleIn` |
| `splitSlideInHorizontal` | `SplitSlideInHorizontal` |
| `splitSlideInOutHorizontal` | `SplitSlideInOutHorizontal` |
| `splitSlideInOutVertical` | `SplitSlideInOutVertical` |
| `splitSlideInVertical` | `SplitSlideInVertical` |
| `splitSlideOutHorizontal` | `SplitSlideOutHorizontal` |
| `splitSlideOutVertical` | `SplitSlideOutVertical` |
| `squeeze` | `Squeeze` |
| `static_wipe` | `StaticWipe` |
| `swap` | `Swap` |
| `tangentMotionBlur` | `TangentMotionBlur` |
| `TVStatic` | `TvStatic` |
| `undulatingBurnOut` | `UndulatingBurnOut` |
| `wind` | `Wind` |
| `windowblinds` | `WindowBlinds` |
| `wipeDown` | `WipeDown` |
| `wipeLeft` | `WipeLeft` |
| `wipeRight` | `WipeRight` |
| `wipeUp` | `WipeUp` |
| `zoomInOut` | `ZoomInOut` |
