---
name: transition-naming
description: Chooses and checks the name of a gl-transitions transition, which is its file name in transitions/ and its identifier in the npm, Rust, Swift and Android packages. Use when adding a transition, renaming one, or reviewing a pull request that adds or renames a file in transitions/.
---

# Naming a transition

A transition's name is its file name without `.glsl` (`transitions/CrossZoom.glsl` is `CrossZoom`). Every package exposes it as the identifier users write in their code (`get("CrossZoom")`, `<Transition name="CrossZoom">`), so a rename breaks them: renames only happen in a major version. The rules are in CONTRIBUTING.md, "Naming"; this skill applies them.

## 1. See what it does

Name the effect, not the code. Before choosing, look at it:

```sh
node scripts/checks/validate-transition.mjs -t transitions/<File>.glsl
node scripts/rendering/render-preview.mjs -t transitions/<File>.glsl -o /tmp/preview.gif
```

Read its `// Description:` line too. Note the direction of any movement (the outgoing image leaves toward…, the incoming one enters from…) and whether that direction is a parameter.

## 2. Draft names

- **PascalCase**, letters and digits only: `CrossZoom`, `WipeLeft`.
- **Acronyms as words**, never three capitals in a row: `HsvFade`, `TvStatic`, `RgbSplit`.
- **What a viewer sees**: `FlowerWipe` (a flower grows), not `PolarFunction` (how the code draws it). Someone scanning the catalog should guess the effect.
- **The family's pattern**:
  - shape reveals end with `Wipe` (`StarWipe`, `HeartWipe`, `LeafWipe`)
  - glitches start with `Glitch` (`GlitchDisplace`, `GlitchFlicker`)
  - dissolves end with `Dissolve` (`BlockDissolve`, `NoiseDissolve`)
  - fades end with `Fade` (`FlashFade`, `RotateScaleFade`)
  - a direction comes last and names the movement: `WipeLeft` moves toward the left; `BowTieVertical`
  - leave a direction out when it is a parameter (`Revolve`, not `RevolveLeft`)
- **No filler**: no `Transition`, `Effect`, `Simple`, `Advanced`, `WithParameter`, no version numbers (`SimpleZoom` and a few other older names predate this rule).
- **Plain words**: describe the shape or motion, not a brand or a product.

## 3. Check it

```sh
node scripts/checks/transition-names.mjs <Name>   # PascalCase, acronyms, unique ignoring case, not a former 1.x name
pnpm run lint                                      # the same rules on every file in transitions/
```

A name that was the 1.x name of another transition (`packages/gl-transitions/renamed.json`) is refused: `Burn` was the 1.x name of `FlashFade`, and code that only fixed the case of the old name would silently get a different effect.

Then search the catalog for the same effect under another name (a duplicate is worse than any name):

```sh
grep -h "^// Description:" transitions/*.glsl | grep -i "<keyword>"
```

## 4. When renaming an existing transition

Only in a major version, and only when the name is wrong, misleading, a typo or a duplicate:

1. `git mv` the file (on macOS, a case-only rename needs `git mv`, not a plain `mv`).
2. Add `"<old name>": "<new name>"` to `packages/gl-transitions/renamed.json`; never remove an entry.
3. Update the references: `git grep -n '"<old name>"'` in the packages, examples, tests, skills and READMEs. Texture names (`luma`, `displacementMap`) are uniforms, not transition names: leave them.
4. Add a major changeset that lists the rename.

## Reviewing a pull request

For each added or renamed file in `transitions/`, check the rules above and say which one a name breaks, with a suggestion that follows the family's pattern. CI runs `pnpm run lint`, which catches the checked rules; the others (what a viewer sees, family, filler, duplicates) need a reviewer.
