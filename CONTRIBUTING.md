# Contributing to gl-transitions

Thanks for your interest in contributing! Here's what you need to know.

## Adding a new transition

### File structure

Place your transition as a **single `.glsl` file** directly in the `transitions/` folder:

```
transitions/MyTransition.glsl    <-- correct
transitions/MyTransition.glsl/MyTransition.glsl   <-- WRONG (GitHub web UI sometimes creates this)
```

Use UTF-8 and LF (Unix) line endings; CI checks both with `pnpm run lint`.

If you use the GitHub web UI to create a file, make sure you type the full path `transitions/MyTransition.glsl` in the filename field, not just `MyTransition.glsl` after navigating into the `transitions/` folder.

### File format

Your `.glsl` file must include:

```glsl
// Author: Your Name
// License: MIT

// Optional: uniform parameters with defaults
uniform float myParam; // = 1.0

vec4 transition(vec2 uv) {
  return mix(
    getFromColor(uv),
    getToColor(uv),
    progress
  );
}
```

### Required elements

1. **Author comment** on the first line: `// Author: Your Name`
2. **License comment** on the second line: `// License: MIT` (MIT is strongly preferred)
3. **`transition` function**: `vec4 transition(vec2 uv)` - the entry point
4. Use **`getFromColor(uv)`** and **`getToColor(uv)`** to sample textures (not `texture2D`)
5. Use the contextual **`progress`** variable (0.0 to 1.0)

### Transition parameters

Define parameters as uniforms with commented default values (GLSL 120 / WebGL 1 does not support uniform initialization):

```glsl
uniform float speed; // = 1.0
uniform vec2 direction; // = vec2(1.0, 0.0)
uniform bool invert; // = false
```

Defaults must match the type: `true` or `false` for `bool` (not `1`), integers for `int`, `vec2(…)` with 1 or 2 values for `vec2`. `pnpm run lint` checks this.

### Description, tags and parameter hints (recommended)

Help people find and use your transition by describing it:

```glsl
// Author: Your Name
// License: MIT
// Description: A ragged left-to-right wipe, as if the image was blown away by the wind
// Tags: wipe, horizontal, noise

// @range(0, 1) Width of the ragged edge
uniform float size; // = 0.2
// @param Wipe from right to left instead
uniform bool reversed; // = false
```

- Put hints (`@range(min, max[, step])`, `@color`, `@param`) on the line **above** the uniform, never after the default value.
- Tags are lowercase; use dashes for multiple words (`zoom-in`).

See [Transition metadata](README.md#transition-metadata-optional) for the full syntax.

### Naming conventions

- Use **PascalCase** for transition names (e.g., `StarWipe.glsl`, `CrossZoom.glsl`)
- Choose a **descriptive name** that reflects what the transition does
- Avoid generic names like `fragment.glsl` or `effect.glsl`

### Before submitting

- Check that your transition is not a duplicate of an existing one
- Test your transition at https://gl-transitions.com/editor if possible
- Adding customizable uniform parameters is encouraged but not mandatory
- Avoid using `#ifdef GL_ES` / `precision mediump float;` (the runtime handles this)

## Updating an existing transition

If you're modifying an existing transition, please explain the motivation in your PR description. Bug fixes and new optional parameters are welcome.

## Spec reference

See the [GL Transition Specification v1](README.md#gl-transition-specification-v1) in the README for full technical details.

## Development

The repository tooling lives in `scripts/` (see [scripts/README.md](scripts/README.md)). It uses ES modules (`.mjs`) and a [pnpm](https://pnpm.io) workspace (`pnpm-workspace.yaml`: the root, `packages/*` and `examples/*`).

[mise](https://mise.jdx.dev) installs the toolchain, the same versions as CI: Node, pnpm and Rust (for the crate, the fframes example and naga, which the shader targets build once), pinned in `mise.toml` with their checksums in `mise.lock`. With mise [activated in your shell](https://mise.jdx.dev/getting-started.html), from the repository root:

```sh
mise install                                                         # Node, pnpm, Rust (with rustfmt and clippy)
pnpm install --filter '!gl-transitions-react-native-skia-example'   # without the Expo example (its native binaries are ~750 MB)
pnpm test
pnpm run lint
pnpm run format
pnpm run validate -t transitions/MyTransition.glsl
```

mise installs Rust with rustup (toolchains in `~/.rustup`, reusing an existing rustup) and selects the pinned version with `RUSTUP_TOOLCHAIN`, so `cargo` uses it anywhere in the repository. The crate's sources are generated from the npm package build:

```sh
pnpm run build && pnpm run build:crate
cd crates/gl-transitions && cargo test
```

Without mise, install the versions of `mise.toml` another way. glslang and naga, for the shader targets, are not in mise: `scripts/targets/toolchain.mjs` pins them and installs them on first use (see [scripts/README.md](scripts/README.md)).

## Releases

Releases are prepared with [changesets](https://github.com/changesets/changesets) (see [.changeset/README.md](.changeset/README.md)):

- A pull request that adds or changes transitions needs nothing more: each one is listed in the changelog of the next release.
- A pull request that changes a published package otherwise (its code, the build scripts, the Agent Skill) adds a changeset with `pnpm changeset`. CI checks it.
- On master, the "Version Packages" pull request collects the pending changes. Merging it publishes the new versions to npm, then the Rust crate to crates.io. Both publish jobs run in the `release` environment, restricted to master, and the npm and crates.io trusted publishers require it.

The Rust crate ([crates/gl-transitions](crates/gl-transitions)) is versioned by changesets too, as the private package `gl-transitions-crate` (its `package.json` only carries the version):

- Each release of the `gl-transitions` npm package bumps the crate's patch version, so that `^0.x` users get the new transitions. A change to the crate's API (`crates/gl-transitions/src`, `scripts/rust-crate/`) adds a changeset for `gl-transitions-crate`, a minor one when it breaks something while the crate is in 0.x.
- `pnpm run changeset:version` copies its version into `Cargo.toml` and the `Cargo.lock` files (`scripts/rust-crate/sync-version.mjs`); a test checks that they agree.
- Once the npm packages are published, CI builds the crate's sources from the published `gl-transitions` package, packages the crate and publishes it with crates.io trusted publishing (no token). The release is tagged `gl-transitions-crate@<version>`, with its GitHub release. A version that is already on crates.io is skipped, and one that failed to publish is retried on the next push to master.
