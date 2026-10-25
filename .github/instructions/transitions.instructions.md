---
applyTo: "transitions/**,packages/gl-transitions/renamed.json"
---

# Reviewing transitions

A transition's file name, without `.glsl`, is its identifier in every package (npm, Rust, Swift, Android). For every file added or renamed in `transitions/`, check its name against these rules (CONTRIBUTING.md, "Naming"; the `transition-naming` skill in `.claude/skills/` has the details):

1. PascalCase, letters and digits only: `CrossZoom`, `WipeLeft`. Flag `snake_case`, `kebab-case`, `camelCase`.
2. Acronyms as words, never three capitals in a row: `HsvFade`, not `HSVFade`.
3. Unique ignoring case, and never a 1.x name listed in `packages/gl-transitions/renamed.json` for a different transition.
4. Describes what a viewer sees, not the code: `FlowerWipe`, not `PolarFunction`.
5. Follows its family: shape reveals end with `Wipe`, glitches start with `Glitch`, dissolves end with `Dissolve`, fades end with `Fade`; a direction comes last and names the movement (`WipeLeft`), and stays out of the name when it is a parameter.
6. No filler: `Transition`, `Effect`, `Simple`, `Advanced`, `WithParameter`, version numbers (older names such as `SimpleZoom` predate this rule).
7. Not a duplicate: compare its `// Description:` with existing transitions doing the same effect.

When a name breaks a rule, say which one and suggest a name that follows the family's pattern. Rules 1 to 3 are also checked by `pnpm run lint` in CI.

Renaming an existing transition breaks users: accept it only in a major version, with an entry added to `packages/gl-transitions/renamed.json` (entries are never removed) and a major changeset.

Transparency (README.md, "Transparency"): the images' alpha must be kept (flag `vec4(color.rgb, 1.0)` and similar), areas where no image is drawn return `vec4(0.0)`, not opaque black, and a fill color is a `vec4` parameter with `@color`.

Also check that the file sits directly in `transitions/` (not `transitions/Name.glsl/Name.glsl`), starts with `// Author:` and `// License:`, and that progress 0 renders the outgoing image and progress 1 the incoming one.
