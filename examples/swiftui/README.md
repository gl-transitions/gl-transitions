# Swift example

A SwiftUI app (macOS 13, iOS 16) that plays the transitions of the [Swift package](../../swift): pick a transition, pause, scrub, tune its parameters.

- **Preview**: the transition between the sample images in an `MTKView`, drawn by `TransitionRenderer` on each frame (`TransitionView.swift`).
- **Video**: three clips made from the sample images (written with `AVAssetWriter` to a temporary directory), put one after the other with the transition between them by `TransitionComposition`, in a `VideoPlayer` (`Video.swift`).

The views are in the `GLTransitionsExample` library, used by the macOS executable `gl-transitions-example` and by the iOS app of `iOS/GLTransitionsExample.xcodeproj`. The package comes from this repository (`../../swift`).

## Run it

```sh
# From the repository root: the npm package build, then the Swift package's catalog
pnpm install && pnpm run build && pnpm run build:swift

cd examples/swiftui
swift run      # the macOS app
swift test     # every transition drawn in the preview, a frame of the video composition
open iOS/GLTransitionsExample.xcodeproj   # the iOS app, to run on a simulator or a device
```

The **Swift package** workflow builds the macOS and iOS apps and runs the tests.
