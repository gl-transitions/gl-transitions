// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "GLTransitionsExample",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        // For the iOS app (iOS/).
        .library(name: "GLTransitionsExample", targets: ["GLTransitionsExample"]),
    ],
    dependencies: [
        .package(path: "../../swift"),
    ],
    targets: [
        // The app's views, shared by the macOS app and an iOS app.
        .target(
            name: "GLTransitionsExample",
            dependencies: [.product(name: "GLTransitions", package: "swift")],
            resources: [.process("SampleImages")],
            // VideoPlayer needs it, but doesn't link it.
            linkerSettings: [.linkedFramework("AVKit")]
        ),
        .executableTarget(name: "gl-transitions-example", dependencies: ["GLTransitionsExample"]),
        .testTarget(name: "GLTransitionsExampleTests", dependencies: ["GLTransitionsExample"]),
    ],
    swiftLanguageModes: [.v5]
)
