---
"gl-transitions": major
"@gl-transitions/react-native-skia": major
"@gl-transitions/remotion": major
"gl-transitions-crate": major
---

Twelve transitions that duplicated another one are removed. Each renders the same as, or very close to, the transition that replaces it with the given parameters:

- `WipeLeft`, `WipeRight`, `WipeUp`, `WipeDown`: `DirectionalWipe` with `smoothness: 0` and `direction` `[-1, 0]`, `[1, 0]`, `[0, 1]` or `[0, -1]` (identical)
- `BowTieVertical`: `BowTie` with its defaults
- `Box`: `InsetWipe`, with `anchor` on the box's corner or at the center, and the new `reverse: true` for `rectIn: 1`
- `LinearBlur`: `DefocusBlur`
- `MosaicBlend`, `MosaicFade`: `Pixelize`
- `ScaleIn`: `SimpleZoomOut` with `zoom_quickness: 1`
- `RotateFade`: `RotateScaleFade` with `scale: 1`
- `BlockDissolve`: `RandomSquares` with `smoothness: 0`

`InsetWipe` gets a `reverse` parameter: the outgoing image shrinks into the rectangle, toward the anchor.
