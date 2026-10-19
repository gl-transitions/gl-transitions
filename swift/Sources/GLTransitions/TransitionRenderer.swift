import Foundation
import Metal

/// Draws transitions between two Metal textures into a third one.
///
/// Each transition's shader is compiled the first time it is drawn (or by `prepare`), then cached.
/// Safe to use from several threads.
public final class TransitionRenderer: @unchecked Sendable {
    public let device: MTLDevice

    private let vertexFunction: MTLFunction
    private let sampler: MTLSamplerState
    private let lock = NSLock()
    private var functions: [String: MTLFunction] = [:]
    private var pipelines: [PipelineKey: MTLRenderPipelineState] = [:]

    private struct PipelineKey: Hashable {
        let name: String
        let pixelFormat: MTLPixelFormat
    }

    // A triangle covering the target, with uv in [0, 1] from its bottom-left corner.
    private static let vertexSource = """
    #include <metal_stdlib>
    struct Varyings {
        float4 position [[position]];
        float2 uv [[user(loc0)]];
    };
    vertex Varyings gl_transitions_vertex(uint id [[vertex_id]]) {
        float2 p = float2((id << 1) & 2, id & 2) * 2.0 - 1.0;
        return { float4(p, 0.0, 1.0), 0.5 * (p + 1.0) };
    }
    """

    public init(device: MTLDevice? = MTLCreateSystemDefaultDevice()) throws {
        guard let device else { throw TransitionError.noMetalDevice }
        self.device = device
        let library = try device.makeLibrary(source: Self.vertexSource, options: nil)
        vertexFunction = library.makeFunction(name: "gl_transitions_vertex")!
        // As the GLSL spec samples: linear, clamped to the edge.
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = .linear
        descriptor.magFilter = .linear
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        sampler = device.makeSamplerState(descriptor: descriptor)!
    }

    /// Compiles the transition for targets of this pixel format, ahead of the first `encode`.
    public func prepare(_ transition: Transition, pixelFormat: MTLPixelFormat = .bgra8Unorm) throws {
        _ = try pipeline(transition, pixelFormat: pixelFormat)
    }

    /// Encodes the transition from `from` to `to` at `progress` (0 to 1), drawn over the whole
    /// `target`. `params` default to the transition's defaults; `textures` must have each of the
    /// transition's extra textures. The images are stretched to the target.
    public func encode(
        _ transition: Transition,
        from: MTLTexture,
        to: MTLTexture,
        progress: Float,
        params: [String: ParamValue] = [:],
        textures: [String: MTLTexture] = [:],
        into target: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) throws {
        for name in textures.keys where !transition.textures.contains(name) {
            throw TransitionError.unknownTexture(transition: transition.name, name: name)
        }
        let extra = try transition.textures.map { name in
            guard let texture = textures[name] else {
                throw TransitionError.missingTexture(transition: transition.name, name: name)
            }
            return texture
        }
        let ratio = Float(target.width) / Float(target.height)
        let uniforms = try transition.uniformBuffer(progress: progress, ratio: ratio, params: params)
        let pipeline = try pipeline(transition, pixelFormat: target.pixelFormat)

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else {
            throw TransitionError.rendering("could not draw into the target (is it a render target?)")
        }
        encoder.label = "gl-transitions \(transition.name)"
        encoder.setRenderPipelineState(pipeline)
        uniforms.withUnsafeBytes { encoder.setFragmentBytes($0.baseAddress!, length: $0.count, index: 0) }
        encoder.setFragmentSamplerState(sampler, index: 0)
        encoder.setFragmentTextures([from, to] + extra, range: 0 ..< 2 + extra.count)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    // Compiled outside the lock, so that drawing cached transitions doesn't wait for a compilation.
    private func pipeline(_ transition: Transition, pixelFormat: MTLPixelFormat) throws -> MTLRenderPipelineState {
        let key = PipelineKey(name: transition.name, pixelFormat: pixelFormat)
        if let pipeline = lock.withLock({ pipelines[key] }) { return pipeline }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = try fragmentFunction(transition)
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        let pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        lock.withLock { pipelines[key] = pipeline }
        return pipeline
    }

    // Each transition is its own library: the translated shaders all name their entry point `main_`.
    private func fragmentFunction(_ transition: Transition) throws -> MTLFunction {
        if let function = lock.withLock({ functions[transition.name] }) { return function }
        do {
            let library = try device.makeLibrary(source: transition.metalSource, options: nil)
            let function = library.makeFunction(name: "main_")!
            lock.withLock { functions[transition.name] = function }
            return function
        } catch {
            throw TransitionError.compilation(transition: transition.name, message: "\(error)")
        }
    }
}
