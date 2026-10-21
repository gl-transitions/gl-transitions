import GLTransitions
import Metal
import MetalKit

/// `Transition` is also a SwiftUI protocol, and `GLTransitions` the module's enum as well: this
/// file doesn't import SwiftUI.
typealias GLTransition = Transition

/// Draws a transition between two of the sample images.
final class PreviewRenderer {
    let renderer: TransitionRenderer
    let commandQueue: MTLCommandQueue
    private let images: [MTLTexture]
    private let extra: MTLTexture

    init(samples: Samples) throws {
        renderer = try TransitionRenderer()
        commandQueue = renderer.device.makeCommandQueue()!
        // As stored, without color conversion: the shaders see the images' values, as in WebGL.
        let loader = MTKTextureLoader(device: renderer.device)
        let options: [MTKTextureLoader.Option: Any] = [.SRGB: false]
        images = try samples.images.map { try loader.newTexture(cgImage: $0, options: options) }
        extra = try loader.newTexture(cgImage: samples.extra, options: options)
    }

    /// From image `image` to the next one.
    func encode(
        _ transition: Transition,
        params: [String: ParamValue],
        image: Int,
        progress: Float,
        into target: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) throws {
        try renderer.encode(
            transition,
            from: images[image % images.count],
            to: images[(image + 1) % images.count],
            progress: progress,
            params: params,
            textures: Dictionary(uniqueKeysWithValues: transition.textures.map { ($0, extra) }),
            into: target,
            commandBuffer: commandBuffer
        )
    }
}
