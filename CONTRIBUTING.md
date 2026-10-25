# Contributing to gl-transitions

Thanks for your interest in contributing! Here's what you need to know.

## Adding a new transition

### File structure

Place your transition as a **single `.glsl` file** directly in the `transitions/` folder:

```
transitions/MyWipe.glsl    <-- correct
transitions/MyWipe.glsl/MyWipe.glsl   <-- WRONG (GitHub web UI sometimes creates this)
```

Use UTF-8 and LF (Unix) line endings; CI checks both with `pnpm run lint`.

If you use the GitHub web UI to create a file, make sure you type the full path `transitions/MyWipe.glsl` in the filename field, not just `MyWipe.glsl` after navigating into the `transitions/` folder.

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
4. Use **`getFromColor(uv)`** and **`getToColor(uv)`** to sample the `from` and `to` images (`texture2D` is only for extra `sampler2D` textures)
5. Use the contextual **`progress`** variable (0.0 to 1.0)
6. **Keep transparency** (see [Transparency](README.md#transparency)): keep the images' alpha, return `vec4(0.0)` where no image is drawn, and make a fill color a `vec4` parameter with `@color`. `pnpm run validate` checks it.

### Transition parameters

Define parameters as uniforms with commented default values (GLSL ES 1.00 / WebGL 1 does not support uniform initialization):

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

### Naming

The file name, without `.glsl`, is the transition's identifier in every package (npm, Rust, Swift, Android). Changing it later breaks everyone who uses the transition, so choose it with care. `pnpm run lint` and CI check the rules marked *(checked)*. To try a name before creating the file, run `node scripts/checks/transition-names.mjs MyName`.

- **PascalCase** *(checked)*: a capital letter, then letters and digits: `CrossZoom`, `WipeLeft`, `ZoomInCircles`. No `_`, `-` or spaces.
- **Acronyms are words** *(checked)*: never three capitals in a row. Write `HsvFade` and `TvStatic`, not `HSVFade` and `TVStatic`.
- **Unique, ignoring case** *(checked)*: macOS and Windows file systems ignore case, so `Crosswarp` next to `CrossWarp` would break a checkout.
- **Never a former name** *(checked)*: a 1.x name (`packages/gl-transitions/renamed.json`) stays with the transition it was renamed to. `Burn` was the 1.x name of `FlashFade`: code that only fixed the case of the old name would silently get a different effect.
- **No `Transition`** *(checked)*: everything in the collection is one. The same goes for filler words such as `Simple`, `Advanced` or `WithParameter` (a few older names, such as `SimpleZoom`, predate this rule).
- **Name what you see, not the code**: `FlowerWipe`, not `PolarFunction`; `ColorWrap`, not `AddColor`. Someone browsing or searching the catalog should guess the effect from the name.
- **Follow the family**: shape reveals end with `Wipe` (`StarWipe`, `HeartWipe`), glitches start with `Glitch` (`GlitchDisplace`), a direction comes last and names the movement (`WipeLeft` moves toward the left, `BowTieVertical`). A direction that is a parameter stays out of the name.
- **Avoid generic names** such as `Fragment` or `Effect`.

Reviewers, human and Copilot (`.github/instructions/transitions.instructions.md`), check these rules on every pull request that adds or renames a transition.

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
pnpm run validate -t transitions/MyWipe.glsl
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
- On master, the "Version Packages" pull request collects the pending changes. Merging it publishes the new versions to npm, then the Rust crate to crates.io, the Swift package to gl-transitions-swift and the Android library to Maven Central. The publish jobs run in the `release` environment, restricted to master, and the npm and crates.io trusted publishers require it; it holds the other secrets.

The Rust crate ([crates/gl-transitions](crates/gl-transitions)) is versioned by changesets too, as the private package `gl-transitions-crate` (its `package.json` only carries the version):

- Each release of the `gl-transitions` npm package bumps the crate's patch version, so that `^0.x` users get the new transitions. A change to the crate's API (`crates/gl-transitions/src`, `scripts/rust-crate/`) adds a changeset for `gl-transitions-crate`, a minor one when it breaks something while the crate is in 0.x.
- `pnpm run changeset:version` copies its version into `Cargo.toml` and the `Cargo.lock` files (`scripts/rust-crate/sync-version.mjs`); a test checks that they agree.
- Once the npm packages are published, CI builds the crate's sources from the published `gl-transitions` package, packages the crate and publishes it with crates.io trusted publishing (no token). The release is tagged `gl-transitions-crate@<version>`, with its GitHub release. A version that is already on crates.io is skipped, and one that failed to publish is retried on the next push to master.

The Swift package ([swift](swift)) and the Android library ([android](android)) take the version of the `gl-transitions` npm package: they need no changeset, and a change to them ships with the next release of the npm package. Once the npm packages are published, CI builds them from the published `gl-transitions` package, as for the crate, and tests them, without secrets; then:

- The Swift package is pushed to [gl-transitions-swift](https://github.com/gl-transitions/gl-transitions-swift), a read-only mirror (SwiftPM installs from git tags): a commit on `main` replacing its content (`scripts/swift-package/build-mirror.mjs`: `swift/` with its catalog, without the `gl-transitions-check` executable), tagged with the version (`scripts/swift-package/publish-mirror.mjs`). The job pushes with a deploy key of that repository (`SWIFT_DEPLOY_KEY`), never force-pushes, and skips a tag that exists.
- The Android library is published by Gradle to a local repository, then signed with GPG (`SIGNING_KEY`, `SIGNING_PASSWORD`) and uploaded to the [Central Portal](https://central.sonatype.com) (`MAVEN_CENTRAL_USERNAME`, `MAVEN_CENTRAL_PASSWORD`: a user token), which releases it once validated; the job holding these secrets builds nothing. A version already on Maven Central is skipped.

As for the crate, a version that failed to publish is retried on the next push to master. On pull requests, the Swift workflow publishes the package to a local repository and installs it from there, and the Android one publishes the library to its local repository.
