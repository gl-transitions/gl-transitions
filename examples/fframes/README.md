# fframes example

Transitions of the [`gl-transitions` crate](../../crates/gl-transitions) in [fframes](https://github.com/dmtrKovalenko/fframes), a Rust video framework rendering with Skia, using fframes from crates.io as `cargo fframes new` sets it up.

- `src/lib.rs`: `GlTransition`, the crate's SkSL as an fframes `Shader` drawn between two `ImageData` (`_from`, `_to`, extra textures, `_resolution`, `progress`, `ratio` and the typed parameters as `ShaderUniforms`). It works the same with video frames: `frame.get_synced_video_frame(..)?.into_image()`.
- **Showcase** (`src/main.rs`): a 960×540 slideshow of the sample images with CrossWarp, Cube, LumaWipe (with a spiral texture), DirectionalWarp, Bounce and Doorway.
- **Check** (`src/bin/check.rs`, `scripts/check.mjs`): every transition between the images of the GLSL reference renders, rendered by fframes' Skia renderer on the CPU and compared with its reference, as the other targets are.

## Run it

```sh
# From the repository root: the toolchain (mise.toml), the npm package build, then the crate's sources
mise install
pnpm install && pnpm run build && pnpm run build:crate

cd examples/fframes
cargo run --release -- render -o out/showcase.mp4   # Metal on macOS, Vulkan elsewhere (--renderer skia-cpu without a GPU)
cargo run --release -- strip -n 12 -o out/strip.png # contact sheet; see --help for frame, inspect…

# Compare with GLSL reference renders (pnpm run render:references --out /tmp/refs, from the root)
node scripts/check.mjs /tmp/refs --renders /tmp/fframes-renders
```

With the Rust of `mise.toml`, it builds as is on macOS. With an older Rust (1.89, for example) and a recent Xcode, linking may fail on `___isPlatformVersionAtLeast` (fframes' prebuilt FFmpeg needs the clang runtime) or on proc macros stripped by Xcode's `strip`: `RUSTFLAGS="-C link-arg=$(xcrun clang --print-resource-dir)/lib/darwin/libclang_rt.osx.a" CARGO_PROFILE_RELEASE_STRIP=none` works around both.

## What fframes can't do yet

- **Scene-to-scene transitions**: shaders take images and video frames, not a rendered scene (an `svgr!` subtree). A transition between two scenes needs each one rendered offscreen to a texture first ([fframes#210](https://github.com/dmtrKovalenko/fframes/issues/210) asks for the same render-to-texture).
- **`int2`/`int3`/`int4` uniforms**: `ShaderUniforms` has no integer vectors, so the 5 transitions with `ivec2` parameters (GridFlip, Pixelize, RandomSquares, SquaresWipe, TilesWave) render with zeros. The check reports them as `unsupported`.
- Images are bound in their own pixels: each one must have the size of the drawn area (`image_of_size` resizes them).
