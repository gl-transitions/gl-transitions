// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "GLTransitions",
    platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .visionOS(.v1)],
    products: [
        .library(name: "GLTransitions", targets: ["GLTransitions"]),
    ],
    targets: [
        .target(name: "GLTransitions"),
        // Renders every transition for the comparison with the GLSL reference renders
        // (scripts/swift-package/check.mjs).
        .executableTarget(name: "gl-transitions-check", dependencies: ["GLTransitions"]),
        .testTarget(name: "GLTransitionsTests", dependencies: ["GLTransitions"]),
    ],
    swiftLanguageModes: [.v5]
)
