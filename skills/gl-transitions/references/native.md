# WebGPU, Rust, Swift, Android

The packages below are built from the npm package, and each npm release publishes them too. The Swift package and the Android library take the npm package's version: use the one of this Skill (the title of `references/catalog.md`, or `version` in `node_modules/gl-transitions/package.json`), written `<version>` below. The Rust crate has its own 0.x version.

A transition a target's compiler rejected has no source for that target (`compatibility.json` in the npm package).

## WGSL and Metal files (WebGPU, wgpu, Bevy, Metal)

`wgsl/<name>.wgsl` and `msl/<name>.metal` in the npm package are complete fragment shaders with the same interface for every transition:

- one uniform buffer (WGSL `@group(0) @binding(0)`, Metal `[[buffer(0)]]`): `progress`, `ratio`, then each parameter in declaration order (`bool` as `i32` 0 or 1), std140 / WGSL uniform layout; `layouts.json` gives each transition's offsets and size in bytes
- one sampler (`@binding(1)` / `[[sampler(0)]]`), then `from`, `to` and the extra textures (`@binding(2)`, ... / `[[texture(0)]]`, ...)
- input uv in [0, 1] with a bottom-left origin at `@location(0)` / `[[user(loc0)]]`, images sampled with a top-left origin; output straight (unpremultiplied) RGBA
- entry point `main` (WGSL) or `main_` (Metal)

The full contract is in the npm package README ("WGSL and Metal contract"). In Rust, Swift and on Android, prefer the packages below: they pack the uniforms for you.

## Rust: crate `gl-transitions`

```toml
gl-transitions = "0.1"   # or: cargo add gl-transitions
```

[crates.io/crates/gl-transitions](https://crates.io/crates/gl-transitions), with its own semver (0.x); each npm release publishes a patch release with its transitions, and `gl_transitions::CATALOG_VERSION` says which npm version they come from. It has the GLSL, SkSL, WGSL, Metal and GLSL ES 3.00 sources with metadata, typed parameters and uniform layouts; no dependencies and no GPU code (bring your own renderer). Each source is a Cargo feature (`sksl`, `wgsl`, `msl`, `glsl3`), all on by default.

```rust
let transition = gl_transitions::get("DirectionalWarp").expect("in the collection");
let mut params = transition.default_params();
params.set("direction", [1.0, 0.0])?;

// SkSL (skia-safe, fframes): children `_from`, `_to` (+ extra textures), uniforms packed for Skia.
// Every source but GLSL is an Option: None when that target's compiler rejected the transition.
let sksl: &str = transition.sksl().expect("has an SkSL version");
let uniforms: Vec<u8> = params.sksl_uniforms(0.5, 1920.0, 1080.0);

// WGSL (wgpu, Bevy): the uniform buffer laid out as the shader declares it.
if let (Some(wgsl), Some(buffer)) = (transition.wgsl(), params.uniform_buffer(0.5, 1920.0 / 1080.0)) {
    // ...
}
```

The crate README (on crates.io, or at `https://github.com/gl-transitions/gl-transitions/tree/gl-transitions@<version>/crates/gl-transitions`) has a skia-safe drawing example; `examples/fframes` in the repository renders transitions in an [fframes](https://github.com/dmtrKovalenko/fframes) video.

## Swift: package `GLTransitions` (Metal, AVFoundation)

iOS 16, macOS 13, tvOS 16, visionOS 1; Xcode 16 or later. Installed with the Swift Package Manager from [gl-transitions-swift](https://github.com/gl-transitions/gl-transitions-swift), which has the npm package's versions:

```swift
.package(url: "https://github.com/gl-transitions/gl-transitions-swift", from: "<version>"),
// target dependency: .product(name: "GLTransitions", package: "gl-transitions-swift")
```

Between video clips (play with `composition.makePlayerItem()`, export with `composition.makeExportSession()`):

```swift
let composition = try await TransitionComposition.make(
    clips: [AVURLAsset(url: first), AVURLAsset(url: second)],
    transitions: [TransitionStep(GLTransitions.named("Cube")!, params: ["persp": .float(0.7)])]
)
```

Between Metal textures:

```swift
let renderer = try TransitionRenderer()
try renderer.encode(
    GLTransitions.named("DirectionalWarp")!,
    from: fromTexture, to: toTexture, progress: 0.5,
    params: ["direction": .vec2(SIMD2(1, 0))],
    into: targetTexture, commandBuffer: commandBuffer
)
```

Extra textures go in `textures:`. `TransitionCompositor` is a `customVideoCompositorClass` for your own `AVMutableVideoComposition`. See the package README at `https://github.com/gl-transitions/gl-transitions/tree/gl-transitions@<version>/swift`.

## Android: `com.gl-transitions:gl-transitions` (AGSL)

On Maven Central with the npm package's versions. The library's `minSdk` is 21 (Android 5.0): the catalog (`GLTransitions`, metadata, AGSL sources) works from there, drawing with `TransitionShader` needs API 33 (Android 13, `RuntimeShader`). The Kotlin package is `com.gltransitions`, unlike the Maven group `com.gl-transitions`.

```kotlin
implementation("com.gl-transitions:gl-transitions:<version>")
```

```kotlin
import com.gltransitions.GLTransitions
import com.gltransitions.ParamValue
import com.gltransitions.TransitionShader

val shader = TransitionShader(GLTransitions.named("DirectionalWarp")!!)
// In a hardware-accelerated View's onDraw, the bitmaps stretched to the canvas:
shader.draw(canvas, fromBitmap, toBitmap, progress, params = mapOf("direction" to ParamValue.vec2(1f, 0f)))
```

For Jetpack Compose or any `Paint`, `update(from, to, progress, width, height, params, textures)` takes `Shader`s drawn at the output size (`TransitionShader.imageShader(bitmap, width, height)`) and `shader.shader` is the `RuntimeShader`. See the library README at `https://github.com/gl-transitions/gl-transitions/tree/gl-transitions@<version>/android`.
