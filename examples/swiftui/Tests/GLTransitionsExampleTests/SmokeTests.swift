import AVFoundation
import GLTransitions
@testable import GLTransitionsExample
import Metal
import XCTest

final class SmokeTests: XCTestCase {
    override func setUpWithError() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("no Metal device") }
    }

    func testEveryTransitionDraws() throws {
        let preview = try PreviewRenderer(samples: Samples.load())
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 256, height: 200, mipmapped: false)
        descriptor.usage = .renderTarget
        let target = try XCTUnwrap(preview.renderer.device.makeTexture(descriptor: descriptor))
        for transition in GLTransitions.all {
            let commandBuffer = try XCTUnwrap(preview.commandQueue.makeCommandBuffer())
            XCTAssertNoThrow(
                try preview.encode(transition, params: [:], image: 0, progress: 0.5, into: target, commandBuffer: commandBuffer),
                transition.name
            )
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            XCTAssertNil(commandBuffer.error, transition.name)
        }
    }

    func testVideoComposition() async throws {
        let samples = try Samples.load()
        let clips = try await Video.makeClips(samples)
        let luma = try XCTUnwrap(GLTransitions.named("LumaWipe"))
        let composition = try await Video.composition(clips: clips, transition: luma, params: [:], samples: samples)
        let duration = try await composition.composition.load(.duration)
        XCTAssertEqual(duration.seconds, 3 * Video.clipDuration - 2 * Video.transitionDuration.seconds, accuracy: 0.05)

        // In the middle of the first transition.
        let generator = AVAssetImageGenerator(asset: composition.composition)
        generator.videoComposition = composition.videoComposition
        let image = try await generator.image(at: CMTime(seconds: 2.25, preferredTimescale: 600)).image
        XCTAssertEqual(image.width, samples.images[0].width)
        XCTAssertEqual(image.height, samples.images[0].height)
    }
}
