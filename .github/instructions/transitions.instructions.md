---
applyTo: "transitions/**"
---

# Reviewing transitions

A transition's file name, without `.glsl`, is its identifier in every package (npm, Rust, Swift, Android). For every file added or renamed in `transitions/`, check its name against these rules (CONTRIBUTING.md, "Naming"; the `transition-naming` skill in `.claude/skills/` has the details):

1. PascalCase, letters and digits only: `CrossZoom`, `StarWipe`. Flag `snake_case`, `kebab-case`, `camelCase`.
2. Acronyms as words, never three capitals in a row: `HsvFade`, not `HSVFade`.
3. Unique ignoring case.
4. Describes what a viewer sees, not the code: `FlowerWipe`, not `PolarFunction`.
5. Follows its family: shape reveals end with `Wipe`, glitches start with `Glitch`, dissolves end with `Dissolve`, fades end with `Fade`; a direction comes last and names the movement (`ZoomWipeLeft`), and stays out of the name when it is a parameter.
6. No filler: `Transition`, `Effect`, `Simple`, `Advanced`, `WithParameter`, version numbers (older names such as `SimpleZoom` predate this rule).
7. Not a duplicate: compare its `// Description:` with existing transitions doing the same effect.

When a name breaks a rule, say which one and suggest a name that follows the family's pattern. Rules 1 to 3 are also checked by `pnpm run lint` in CI.

Renaming an existing transition breaks users: accept it only in a major version, with a major changeset that lists the rename.

Transparency (README.md, "Transparency"): the images' alpha must be kept (flag `vec4(color.rgb, 1.0)` and similar), areas where no image is drawn return `vec4(0.0)`, not opaque black, and a fill color is a `vec4` parameter with `@color`.

Also check that the file sits directly in `transitions/` (not `transitions/Name.glsl/Name.glsl`), starts with `// Author:` and `// License:`, and that progress 0 renders the outgoing image and progress 1 the incoming one.

Comments (CONTRIBUTING.md, "Required elements"): flag comments that restate the code (`// compute the angle`, `// anti-alias`), section banners and `// ----` dividers, numbered step-by-step narration, function comments that repeat the function's name, and commented-out code. A comment should say why (a math trick, the reason for a constant, a precision or portability workaround), in one short line when possible. Header lines, `@param`/`@range`/`@color` hints and `// = default` comments are metadata and stay.

Continuity (CONTRIBUTING.md, "Required elements"): the transition must be a continuous function of `progress` that leaves the outgoing image and converges to the incoming one by itself. Flag any early return on the ends, such as `if (progress <= 0.0) return getFromColor(uv);` or `if (progress >= 1.0) return getToColor(uv);`: it only makes the frames at exactly 0 and 1 right and hides a jump on the first and last frames (watch the preview GIF's first frames for one). Ask for the effect itself to fade out at the ends instead, for example by scaling it with an envelope that is 0 at both ends.
