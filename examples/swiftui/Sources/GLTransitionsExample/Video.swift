import AVFoundation
import AVKit
import Combine
import GLTransitions
import SwiftUI

enum Video {
    /// Each clip lasts `clipDuration` seconds, overlapping the next one for the transition's duration.
    static let clipDuration = 3.0
    static let transitionDuration = CMTime(value: 3, timescale: 2)

    /// Writes a clip per sample image, a slow zoom into it, to a new temporary directory.
    static func makeClips(_ samples: Samples) async throws -> [URL] {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("gl-transitions-example-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var urls: [URL] = []
        for (i, image) in samples.images.enumerated() {
            let url = directory.appendingPathComponent("clip-\(i + 1).mov")
            try await writeClip(image, to: url)
            urls.append(url)
        }
        return urls
    }

    private static func writeClip(_ image: CGImage, to url: URL) async throws {
        let (width, height, fps) = (image.width, image.height, 30)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(input)
        guard writer.startWriting(), let pool = adaptor.pixelBufferPool else {
            throw writer.error ?? CocoaError(.fileWriteUnknown)
        }
        writer.startSession(atSourceTime: .zero)
        let frames = Int(clipDuration) * fps
        for frame in 0 ..< frames {
            var buffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
            guard let buffer else { throw CocoaError(.fileWriteUnknown) }
            CVPixelBufferLockBaseAddress(buffer, [])
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            )!
            let zoom = 1 + 0.15 * CGFloat(frame) / CGFloat(frames)
            let (w, h) = (CGFloat(width) * zoom, CGFloat(height) * zoom)
            context.draw(image, in: CGRect(x: (CGFloat(width) - w) / 2, y: (CGFloat(height) - h) / 2, width: w, height: h))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(fps))) else {
                throw writer.error ?? CocoaError(.fileWriteUnknown)
            }
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
    }

    /// The clips one after the other, with the transition between each of them.
    static func composition(
        clips: [URL],
        transition: GLTransition,
        params: [String: ParamValue],
        samples: Samples
    ) async throws -> TransitionComposition {
        let step = TransitionStep(
            transition,
            duration: transitionDuration,
            params: params,
            textures: Dictionary(uniqueKeysWithValues: transition.textures.map { ($0, samples.extra) })
        )
        return try await TransitionComposition.make(
            clips: clips.map { AVURLAsset(url: $0) },
            transitions: Array(repeating: step, count: clips.count - 1)
        )
    }
}

@MainActor
final class VideoModel: ObservableObject {
    let player = AVPlayer()
    @Published var error: String?

    init() {
        player.actionAtItemEnd = .none
    }

    /// Shows the composition with this transition, from where the previous one was, playing unless
    /// it was paused.
    func load(_ transition: GLTransition, params: [String: ParamValue], clips: Task<[URL], Error>, samples: Samples) async {
        do {
            let clips = try await clips.value
            let composition = try await Video.composition(clips: clips, transition: transition, params: params, samples: samples)
            try Task.checkCancellation()
            let time = player.currentTime()
            let playing = player.currentItem == nil || player.rate != 0
            player.replaceCurrentItem(with: composition.makePlayerItem())
            await player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            if playing { player.play() }
            error = nil
        } catch is CancellationError {
        } catch {
            self.error = "\(error)"
        }
    }

    func loop(_ notification: Notification) {
        guard notification.object as? AVPlayerItem === player.currentItem else { return }
        player.seek(to: .zero)
        player.play()
    }
}

/// The clips made from the sample images, with the transition between them, in an AVPlayer.
struct VideoPreview: View {
    let transition: GLTransition
    let params: [String: ParamValue]
    let samples: Samples
    let clips: Task<[URL], Error>
    @StateObject private var model = VideoModel()

    private struct Key: Hashable {
        let transition: GLTransition
        let params: [String: ParamValue]
    }

    var body: some View {
        VideoPlayer(player: model.player)
            .overlay {
                if let error = model.error { Text(error).foregroundStyle(.red).padding() }
            }
            .task(id: Key(transition: transition, params: params)) {
                // Waits for the parameters to settle before making the composition again.
                if model.player.currentItem != nil {
                    do { try await Task.sleep(nanoseconds: 300_000_000) } catch { return }
                }
                await model.load(transition, params: params, clips: clips, samples: samples)
            }
            .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime).receive(on: DispatchQueue.main), perform: model.loop)
            .onDisappear { model.player.pause() }
    }
}
