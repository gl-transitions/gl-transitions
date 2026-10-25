# GLTransitions for Swift

The [gl-transitions](https://gl-transitions.com) collection for Apple platforms: 100+ transitions between two images as Metal shaders, with their metadata and typed parameters, a Metal renderer, and an AVFoundation compositor to put transitions between video clips. iOS 16, macOS 13, tvOS 16, visionOS 1; Xcode 16 or later.

## Installation

With the Swift Package Manager, from [gl-transitions-swift](https://github.com/gl-transitions/gl-transitions-swift), where each release of the [gl-transitions npm package](https://www.npmjs.com/package/gl-transitions) is published with the same version (in Xcode: File > Add Package Dependencies…):

```swift
.package(url: "https://github.com/gl-transitions/gl-transitions-swift", from: "1.76.1"),
```

and `.product(name: "GLTransitions", package: "gl-transitions-swift")` in your target's dependencies.

## Transitions between video clips

```swift
import AVFoundation
import GLTransitions

let composition = try await TransitionComposition.make(
    clips: [AVURLAsset(url: first), AVURLAsset(url: second), AVURLAsset(url: third)],
    transitions: [
        TransitionStep(GLTransitions.named("CrossWarp")!),
        TransitionStep(GLTransitions.named("Cube")!, duration: CMTime(value: 3, timescale: 2), params: ["persp": .float(0.7)]),
    ]
)

// Play it…
let player = AVPlayer(playerItem: composition.makePlayerItem())
// …or export it.
let export = composition.makeExportSession()
```

Each transition overlaps the end of a clip with the start of the next one (1 second by default), and the audio crossfades. A clip is its video track. Every frame is stretched to the size of the first clip; the tracks' `preferredTransform` (a portrait iPhone video) is not applied.

For your own compositions, `TransitionInstruction` describes a segment (a track as is, or a transition from one track to another over its time range) and `TransitionCompositor` draws them: set it as the `customVideoCompositorClass` of your `AVMutableVideoComposition`.

## Transitions between Metal textures

```swift
let renderer = try TransitionRenderer() // the default Metal device
let transition = GLTransitions.named("DirectionalWarp")!

try renderer.encode(
    transition,
    from: fromTexture, to: toTexture,
    progress: 0.5,
    params: ["direction": .vec2(SIMD2(1, 0))], // the others keep their defaults
    into: targetTexture, // any color render target; the images are stretched to it
    commandBuffer: commandBuffer
)
```

Transitions with extra textures (`transition.textures`, e.g. `luma`) take them in `textures:`. Parameters are checked against the transition (`TransitionError`). Each transition's shader is compiled the first time it is drawn, which takes some tens of milliseconds: `renderer.prepare(transition)` compiles it ahead of time.

## The collection

`GLTransitions.all` lists the transitions, `GLTransitions.named(_:)` finds one. Each `GLTransition` has its `name`, `author`, `license`, `description`, `tags`, `params` (type, default, range, whether it is a color), extra `textures`, its Metal source (`metalSource`) and its `uniformLayout`, to draw it with your own renderer; `uniformBuffer(progress:ratio:params:)` packs its uniforms. The bindings are those of the [Metal files of the npm package](https://github.com/gl-transitions/gl-transitions/tree/master/packages/gl-transitions#wgsl-and-metal-contract).

`GLTransitions.catalogVersion` is the version of the [gl-transitions npm package](https://www.npmjs.com/package/gl-transitions) the transitions come from; their Metal sources are translated from the original GLSL by [naga](https://github.com/gfx-rs/wgpu/tree/trunk/naga). In CI, every transition is rendered with this package's renderer and compared with the GLSL reference renders.

## Development

This package is built in the [gl-transitions repository](https://github.com/gl-transitions/gl-transitions): its catalog (`Sources/GLTransitions/Generated/`) and `LICENSES.md` are generated from the npm package build and not committed. CI publishes it to [gl-transitions-swift](https://github.com/gl-transitions/gl-transitions-swift) with each release of the npm package.

```sh
# From the repository root
pnpm install && pnpm run build && pnpm run build:swift
cd swift && swift test

# Compare every transition with the GLSL reference renders
node scripts/rendering/render-references.mjs --out /tmp/refs
node scripts/swift-package/check.mjs /tmp/refs
```

## License

MIT ([LICENSE](LICENSE)). Each transition keeps the license of its source (`license`): MIT for nearly all of them, BSD for a few, whose notices and conditions are in `LICENSES.md`.
