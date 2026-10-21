import AVFoundation
import CoreVideo
import Metal
import MetalKit

/// A segment of a video composition drawn by `TransitionCompositor`: a track as is, or a transition
/// from one track to another whose progress goes from 0 to 1 over `timeRange`.
public final class TransitionInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    public let timeRange: CMTimeRange
    public let enablePostProcessing = false
    public let containsTweening: Bool
    public let requiredSourceTrackIDs: [NSValue]?
    public let passthroughTrackID: CMPersistentTrackID

    public let transition: GLTransition?
    public let fromTrackID: CMPersistentTrackID
    public let toTrackID: CMPersistentTrackID
    public let params: [String: ParamValue]
    /// The transition's extra textures (e.g. `luma`).
    public let textures: [String: CGImage]

    /// Shows the frames of `trackID` as they are.
    public init(passthrough trackID: CMPersistentTrackID, timeRange: CMTimeRange) {
        self.timeRange = timeRange
        containsTweening = false
        requiredSourceTrackIDs = nil
        passthroughTrackID = trackID
        transition = nil
        fromTrackID = trackID
        toTrackID = trackID
        params = [:]
        textures = [:]
    }

    public init(
        _ transition: GLTransition,
        from fromTrackID: CMPersistentTrackID,
        to toTrackID: CMPersistentTrackID,
        timeRange: CMTimeRange,
        params: [String: ParamValue] = [:],
        textures: [String: CGImage] = [:]
    ) {
        self.timeRange = timeRange
        containsTweening = true
        requiredSourceTrackIDs = [NSNumber(value: fromTrackID), NSNumber(value: toTrackID)]
        passthroughTrackID = kCMPersistentTrackID_Invalid
        self.transition = transition
        self.fromTrackID = fromTrackID
        self.toTrackID = toTrackID
        self.params = params
        self.textures = textures
    }
}

/// The custom video compositor of compositions made of `TransitionInstruction`s: set it as the
/// `customVideoCompositorClass` of the video composition (`TransitionComposition` does).
public final class TransitionCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private static let pixelBufferAttributes: [String: any Sendable] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        kCVPixelBufferMetalCompatibilityKey as String: true,
    ]

    public let sourcePixelBufferAttributes: [String: any Sendable]? = pixelBufferAttributes
    public let requiredPixelBufferAttributesForRenderContext: [String: any Sendable] = pixelBufferAttributes

    private let queue = DispatchQueue(label: "gl-transitions.compositor")
    private let lock = NSLock()
    private var cancelling = false
    // Created on the first request, on `queue`.
    private var gpu: GPU?
    private var images: [ObjectIdentifier: (CGImage, MTLTexture)] = [:]

    private struct GPU {
        let renderer: TransitionRenderer
        let commandQueue: MTLCommandQueue
        let textureCache: CVMetalTextureCache
        let textureLoader: MTKTextureLoader
    }

    override public init() {}

    public func renderContextChanged(_: AVVideoCompositionRenderContext) {}

    public func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        queue.async { [self] in
            if lock.withLock({ cancelling }) {
                request.finishCancelledRequest()
                return
            }
            do {
                try render(request)
            } catch {
                request.finish(with: error)
            }
        }
    }

    public func cancelAllPendingVideoCompositionRequests() {
        lock.withLock { cancelling = true }
        queue.async { [self] in lock.withLock { cancelling = false } }
    }

    // Encodes the frame on `queue` and finishes the request when the GPU is done, so that the next
    // frames are encoded meanwhile.
    private func render(_ request: AVAsynchronousVideoCompositionRequest) throws {
        guard let instruction = request.videoCompositionInstruction as? TransitionInstruction else {
            throw TransitionError.videoComposition("the instructions must be TransitionInstructions")
        }
        guard let transition = instruction.transition else {
            guard let frame = request.sourceFrame(byTrackID: instruction.passthroughTrackID) else {
                throw TransitionError.videoComposition("no frame of track \(instruction.passthroughTrackID)")
            }
            request.finish(withComposedVideoFrame: frame)
            return
        }
        guard let from = request.sourceFrame(byTrackID: instruction.fromTrackID),
              let to = request.sourceFrame(byTrackID: instruction.toTrackID)
        else {
            throw TransitionError.videoComposition("no frame of track \(instruction.fromTrackID) or \(instruction.toTrackID)")
        }
        guard let output = request.renderContext.newPixelBuffer() else {
            throw TransitionError.videoComposition("no output pixel buffer")
        }
        let gpu = try self.gpu ?? makeGPU()
        self.gpu = gpu

        let range = instruction.timeRange
        let elapsed = CMTimeGetSeconds(CMTimeSubtract(request.compositionTime, range.start))
        let progress = Float(min(max(elapsed / CMTimeGetSeconds(range.duration), 0), 1))
        // The CVMetalTextures must live until the GPU is done with them.
        let buffers = try [from, to, output].map { try texture(of: $0, cache: gpu.textureCache) }
        let textures = try instruction.textures.mapValues { try texture(of: $0, loader: gpu.textureLoader) }
        guard let commandBuffer = gpu.commandQueue.makeCommandBuffer() else {
            throw TransitionError.videoComposition("no command buffer")
        }
        try gpu.renderer.encode(
            transition,
            from: CVMetalTextureGetTexture(buffers[0])!,
            to: CVMetalTextureGetTexture(buffers[1])!,
            progress: progress,
            params: instruction.params,
            textures: textures,
            into: CVMetalTextureGetTexture(buffers[2])!,
            commandBuffer: commandBuffer
        )
        commandBuffer.addCompletedHandler { commandBuffer in
            withExtendedLifetime(buffers) {
                if let error = commandBuffer.error {
                    request.finish(with: error)
                } else {
                    // Tagged with the color space of the clip, as its frames shown as they are.
                    CVBufferPropagateAttachments(from, output)
                    request.finish(withComposedVideoFrame: output)
                }
            }
        }
        commandBuffer.commit()
        CVMetalTextureCacheFlush(gpu.textureCache, 0)
    }

    private func makeGPU() throws -> GPU {
        let renderer = try TransitionRenderer()
        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, renderer.device, nil, &cache)
        guard let cache, let commandQueue = renderer.device.makeCommandQueue() else {
            throw TransitionError.videoComposition("could not set up Metal")
        }
        return GPU(renderer: renderer, commandQueue: commandQueue, textureCache: cache, textureLoader: MTKTextureLoader(device: renderer.device))
    }

    private func texture(of buffer: CVPixelBuffer, cache: CVMetalTextureCache) throws -> CVMetalTexture {
        var texture: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(
            nil, cache, buffer, nil, .bgra8Unorm,
            CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), 0, &texture
        )
        guard let texture else { throw TransitionError.videoComposition("could not read a frame as a Metal texture") }
        return texture
    }

    // Kept with their image, so that an identifier is not reused while it is cached; a composition
    // has a few of them.
    private func texture(of image: CGImage, loader: MTKTextureLoader) throws -> MTLTexture {
        let id = ObjectIdentifier(image)
        if let (_, texture) = images[id] { return texture }
        let texture = try loader.newTexture(cgImage: image, options: [.SRGB: false])
        if images.count >= 16 { images.removeAll() }
        images[id] = (image, texture)
        return texture
    }
}
