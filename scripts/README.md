# Repository scripts

Everything that builds, checks and renders the collection. All scripts are ES modules (`.mjs`) with one set of dependencies in the root `package.json`:

```sh
npm ci             # gl (headless WebGL, for rendering) is optional: it builds on Node 22 (.nvmrc)
npm test           # unit tests (scripts/**/*.test.mjs)
npm run lint       # layout, encoding and parsing of transitions/
npm run build      # the npm package, in release/
```

| Folder | What it does |
|---|---|
| `catalog/` | Parses each `.glsl` (uniforms, defaults, annotations) into `gl-transitions.json` (`build-catalog.mjs`) |
| `checks/` | `lint-transitions.mjs` (folder layout, UTF-8, LF, header and parameter defaults) and `validate-transition.mjs` (spec checks shown in PR previews) |
| `rendering/` | Headless GLSL rendering: reference strips (`render-references.mjs`) and PR preview GIFs (`render-preview.mjs`) |
| `targets/` | Conversion to other shader languages, checked against the reference renders (SkSL today) |
| `agents/` | Documents for coding agents, generated from the catalog: `llms.txt`, `llms-full.txt` and the Agent Skill's catalog (`build-agent-docs.mjs`) |
| `npm-package/` | `build.sh` and the `skeleton/` of the published package |

The reference renders are the ground truth for every other target: each target renders the same procedural images at the same progress values and is compared pixel by pixel. CI (**Reference renders** workflow) also renders the base branch and the PR to report transitions whose output changed.

```sh
npm run render:references -- --out /tmp/refs
npm run build:sksl -- --out /tmp/sksl --refs /tmp/refs --renders /tmp/sksl-renders --report /tmp/sksl.json
```

## SkSL

`targets/build-sksl.mjs` converts each transition into a standalone [SkSL](https://skia.org/docs/user/sksl/) runtime effect, compiles it with Skia (CanvasKit), renders it with the same input images as the GLSL reference and compares the two.

### Shader contract

Every generated `.sksl` file has the same interface:

| | Name | Notes |
|---|---|---|
| child | `_from`, `_to` | The two images, drawn at the output size |
| child | one per extra texture | Same name as the GLSL `sampler2D` (listed in `textures` of `gl-transitions.json`) |
| uniform | `float2 _resolution` | Output size in pixels |
| uniform | `float progress`, `float ratio` | As in the GLSL spec |
| uniform | each parameter | Same name and type; `bool` parameters are `int` (0 or 1) |
| entry | `half4 main(float2 coord)` | Pixel coordinates, top-left origin |

Transitions see straight (unpremultiplied) colors, as in the GLSL spec; the output is premultiplied, as Skia expects.

### Conversion

1. Preprocess (`targets/glsl-preprocess.mjs`): strip comments, expand `#define` macros, drop `#ifdef GL_ES` blocks.
2. Map extra `sampler2D` inputs to child shaders and `texture2D(x, uv)` to a sampling helper.
3. Turn `bool` uniforms into `int` uniforms.
4. Add the wrapper (children, uniforms, `getFromColor` / `getToColor`, `main`).

### Comparison statuses

| Status | Meaning |
|---|---|
| `match` | At most 1% of pixels differ by more than 16/255 in every frame |
| `close` | At most 5% |
| `noise-only` | Uses hash noise (`fract(sin(x) * 43758.5453)`) and matches when compared as 10×10 block averages |
| `differs` | Anything else. Transitions flagged `hashNoise` pick random tiles or shapes, which legitimately differ between implementations |
| `no-reference` | The GLSL reference render is missing or has another size, so nothing was compared |
| `compile-error` | Skia rejected the generated shader |
| `unsupported` | The converter can't handle the source |

## Agent documents

`agents/build-agent-docs.mjs` runs at the end of `npm run build` and adds to the package:

| File | Content |
|---|---|
| `llms.txt` | [llms.txt](https://llmstxt.org/) index: summary, the GLSL contract, docs links and one line per transition |
| `llms-full.txt` | Every transition with its description, tags, typed parameters (defaults, ranges), author, license and GLSL / SkSL / preview links |
| `skills/gl-transitions/` | The Agent Skill from [`skills/gl-transitions/`](../skills/gl-transitions/SKILL.md), plus the generated `references/catalog.md` (tag index, one line per transition) |

Links point to the exact package version on jsDelivr. The skill's integration guides (`references/*.md`) are written by hand; `agents/agent-docs.test.mjs` checks the `bakeParams` snippet against every transition.
