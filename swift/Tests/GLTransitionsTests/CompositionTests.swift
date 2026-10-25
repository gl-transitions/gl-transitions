import AVFoundation
import GLTransitions
import XCTest

final class CompositionTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        guard MTLCreateSystemDefaultDevice() != nil else { throw XCTSkip("no Metal device") }
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    /// A one-color H.264 movie of 30 frames per second.
    private func movie(_ name: String, color: (UInt8, UInt8, UInt8), seconds: Int = 2, size: Int = 64) async throws -> AVAsset {
        let url = directory.appendingPathComponent("\(name).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: size, AVVideoHeightKey: size,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: size, kCVPixelBufferHeightKey as String: size,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0 ..< seconds * 30 {
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
            CVPixelBufferLockBaseAddress(buffer!, [])
            let pixels = CVPixelBufferGetBaseAddress(buffer!)!.assumingMemoryBound(to: UInt8.self)
            for i in 0 ..< CVPixelBufferGetDataSize(buffer!) / 4 {
                (pixels[4 * i], pixels[4 * i + 1], pixels[4 * i + 2], pixels[4 * i + 3]) = (color.2, color.1, color.0, 255)
            }
            CVPixelBufferUnlockBaseAddress(buffer!, [])
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
            adaptor.append(buffer!, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed, "\(writer.error.map { "\($0)" } ?? "")")
        return AVURLAsset(url: url)
    }

    private func image(at seconds: Double, of composition: TransitionComposition) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: composition.composition)
        generator.videoComposition = composition.videoComposition
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        return try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600)).image
    }

    private func color(at seconds: Double, of composition: TransitionComposition) async throws -> (Int, Int, Int) {
        let image = try await image(at: seconds, of: composition)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = CGContext(
            data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: -image.width / 2, y: -image.height / 2, width: image.width, height: image.height))
        return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
    }

    private func assertColor(_ actual: (Int, Int, Int), _ expected: (Int, Int, Int), tolerance: Int = 8, file: StaticString = #filePath, line: UInt = #line) {
        let close = abs(actual.0 - expected.0) <= tolerance && abs(actual.1 - expected.1) <= tolerance && abs(actual.2 - expected.2) <= tolerance
        XCTAssertTrue(close, "\(actual) is not \(expected)", file: file, line: line)
    }

    func testFadeBetweenClips() async throws {
        let redClip = try await movie("red", color: (255, 0, 0))
        let blueClip = try await movie("blue", color: (0, 0, 255))
        let fade = try XCTUnwrap(GLTransitions.named("Fade"))
        let composition = try await TransitionComposition.make(clips: [redClip, blueClip], transitions: [TransitionStep(fade)])

        // 2 s + 2 s overlapping by 1 s.
        XCTAssertEqual(composition.composition.duration.seconds, 3, accuracy: 0.01)
        XCTAssertEqual(composition.videoComposition.renderSize, CGSize(width: 64, height: 64))
        XCTAssertEqual(composition.videoComposition.instructions.count, 3)
        // The frames shown as they are and the transition's look the same where they meet (the
        // H.264 round trip and color management shift both alike).
        let red = try await color(at: 0.5, of: composition)
        let blue = try await color(at: 2.5, of: composition)
        assertColor(red, (255, 0, 0), tolerance: 40)
        assertColor(blue, (0, 0, 255), tolerance: 40)
        assertColor(try await color(at: 1.01, of: composition), red)
        // Mixed in the clips' color space, before the conversion for display: about halfway.
        assertColor(try await color(at: 1.5, of: composition), ((red.0 + blue.0) / 2, (red.1 + blue.1) / 2, (red.2 + blue.2) / 2), tolerance: 16)
        assertColor(try await color(at: 1.99, of: composition), blue)
    }

    func testClipsOfAnotherSizeAreStretched() async throws {
        let small = try await movie("small", color: (255, 0, 0))
        let large = try await movie("large", color: (0, 0, 255), size: 128)
        let fade = try XCTUnwrap(GLTransitions.named("Fade"))
        let composition = try await TransitionComposition.make(clips: [small, large], transitions: [TransitionStep(fade)])
        XCTAssertEqual(composition.videoComposition.renderSize, CGSize(width: 64, height: 64))
        for seconds in [0.5, 1.5, 2.5] {
            let image = try await image(at: seconds, of: composition)
            XCTAssertEqual(CGSize(width: image.width, height: image.height), CGSize(width: 64, height: 64), "at \(seconds) s")
        }
        let blue = try await color(at: 2.5, of: composition)
        assertColor(blue, (0, 0, 255), tolerance: 40)
    }

    func testValidation() async throws {
        let clip = try await movie("clip", color: (0, 0, 0), seconds: 1)
        let fade = try XCTUnwrap(GLTransitions.named("Fade"))
        do {
            _ = try await TransitionComposition.make(clips: [clip, clip], transitions: [])
            XCTFail("a transition is missing")
        } catch {}
        do {
            _ = try await TransitionComposition.make(clips: [clip, clip], transitions: [TransitionStep(fade, duration: CMTime(value: 2, timescale: 1))])
            XCTFail("the transition is longer than the clips")
        } catch {}
        do {
            _ = try await TransitionComposition.make(clips: [clip, clip], transitions: [TransitionStep(fade, duration: .zero)])
            XCTFail("the transition lasts zero")
        } catch {}
    }
}
