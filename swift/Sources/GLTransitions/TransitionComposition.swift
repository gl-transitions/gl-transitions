import AVFoundation

/// A transition between two clips of a `TransitionComposition`.
public struct TransitionStep {
    public var transition: GLTransition
    /// How long the two clips overlap.
    public var duration: CMTime
    public var params: [String: ParamValue]
    /// The transition's extra textures (e.g. `luma`).
    public var textures: [String: CGImage]

    public init(
        _ transition: GLTransition,
        duration: CMTime = CMTime(value: 1, timescale: 1),
        params: [String: ParamValue] = [:],
        textures: [String: CGImage] = [:]
    ) {
        self.transition = transition
        self.duration = duration
        self.params = params
        self.textures = textures
    }
}

/// Clips played one after the other with transitions between them, ready for an `AVPlayerItem` or
/// an `AVAssetExportSession`.
public struct TransitionComposition {
    public let composition: AVComposition
    /// Drawn by `TransitionCompositor`.
    public let videoComposition: AVVideoComposition
    /// Crossfades the clips' audio during the transitions.
    public let audioMix: AVAudioMix

    public func makePlayerItem() -> AVPlayerItem {
        let item = AVPlayerItem(asset: composition)
        item.videoComposition = videoComposition
        item.audioMix = audioMix
        return item
    }

    public func makeExportSession(presetName: String = AVAssetExportPresetHighestQuality) -> AVAssetExportSession? {
        let session = AVAssetExportSession(asset: composition, presetName: presetName)
        session?.videoComposition = videoComposition
        session?.audioMix = audioMix
        return session
    }

    /// The clips one after the other (each one is its video track), `transitions[i]` overlapping the
    /// end of `clips[i]` with the start of `clips[i + 1]`. Every frame is stretched to `renderSize`, by
    /// default the size of the first clip's video track; the tracks' `preferredTransform` (e.g. a
    /// portrait iPhone video) is not applied.
    public static func make(
        clips: [AVAsset],
        transitions: [TransitionStep],
        renderSize: CGSize? = nil,
        frameDuration: CMTime? = nil
    ) async throws -> TransitionComposition {
        guard !clips.isEmpty, transitions.count == clips.count - 1 else {
            throw TransitionError.videoComposition("\(clips.count) clips need \(max(clips.count - 1, 0)) transitions, not \(transitions.count)")
        }
        for (i, step) in transitions.enumerated() where !(step.duration > .zero) {
            throw TransitionError.videoComposition("transition \(i) must last more than zero")
        }
        let composition = AVMutableComposition()
        // The clips alternate between two tracks, so that each transition has both clips' frames.
        let videoTracks = (0 ..< 2).map { _ in composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)! }
        var audioTracks: [AVMutableCompositionTrack] = []
        var clipSizes: [CGSize] = []
        var segments: [(track: Int, shown: CMTimeRange, transition: (step: TransitionStep, range: CMTimeRange)?)] = []
        var start = CMTime.zero

        for (i, clip) in clips.enumerated() {
            guard let video = try await clip.loadTracks(withMediaType: .video).first else {
                throw TransitionError.videoComposition("clip \(i) has no video track")
            }
            // The clip is its video track; its audio, where it overlaps it.
            let (clipRange, size) = try await video.load(.timeRange, .naturalSize)
            clipSizes.append(size)
            let incoming = i > 0 ? transitions[i - 1].duration : .zero
            let outgoing = i < transitions.count ? transitions[i].duration : .zero
            guard CMTimeAdd(incoming, outgoing) <= clipRange.duration else {
                throw TransitionError.videoComposition("clip \(i) is shorter than its transitions")
            }
            let track = i % 2
            try videoTracks[track].insertTimeRange(clipRange, of: video, at: start)
            if let audio = try await clip.loadTracks(withMediaType: .audio).first {
                let audioRange = CMTimeRangeGetIntersection(try await audio.load(.timeRange), otherRange: clipRange)
                if audioRange.duration > .zero {
                    if audioTracks.isEmpty {
                        audioTracks = (0 ..< 2).map { _ in composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)! }
                    }
                    let at = CMTimeAdd(start, CMTimeSubtract(audioRange.start, clipRange.start))
                    try audioTracks[track].insertTimeRange(audioRange, of: audio, at: at)
                }
            }

            let end = CMTimeAdd(start, clipRange.duration)
            let shown = CMTimeRange(start: CMTimeAdd(start, incoming), end: CMTimeSubtract(end, outgoing))
            let transition = i < transitions.count ? (transitions[i], CMTimeRange(start: shown.end, end: end)) : nil
            segments.append((track, shown, transition))
            if let transition { start = transition.1.start }
        }

        let renderSize = renderSize ?? clipSizes[0]
        // Frames of another size go through the compositor too, which stretches them (a fade
        // from a frame to itself).
        let stretch = GLTransitions.named("Fade")!
        var instructions: [TransitionInstruction] = []
        var audioRamps: [(track: Int, from: Float, to: Float, range: CMTimeRange)] = []
        for (i, segment) in segments.enumerated() {
            let trackID = videoTracks[segment.track].trackID
            if segment.shown.duration > .zero {
                instructions.append(
                    clipSizes[i] == renderSize
                        ? TransitionInstruction(passthrough: trackID, timeRange: segment.shown)
                        : TransitionInstruction(stretch, from: trackID, to: trackID, timeRange: segment.shown)
                )
            }
            if let (step, range) = segment.transition {
                instructions.append(TransitionInstruction(
                    step.transition,
                    from: trackID,
                    to: videoTracks[1 - segment.track].trackID,
                    timeRange: range,
                    params: step.params,
                    textures: step.textures
                ))
                audioRamps.append((segment.track, 1, 0, range))
                audioRamps.append((1 - segment.track, 0, 1, range))
            }
        }

        let videoComposition = AVMutableVideoComposition()
        videoComposition.customVideoCompositorClass = TransitionCompositor.self
        videoComposition.instructions = instructions
        videoComposition.renderSize = renderSize
        if let frameDuration {
            videoComposition.frameDuration = frameDuration
        } else {
            let video = try await clips[0].loadTracks(withMediaType: .video)[0]
            let rate = try await video.load(.nominalFrameRate)
            videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(rate > 0 ? rate.rounded() : 30))
        }

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = audioTracks.enumerated().map { index, track in
            let parameters = AVMutableAudioMixInputParameters(track: track)
            for ramp in audioRamps where ramp.track == index {
                parameters.setVolumeRamp(fromStartVolume: ramp.from, toEndVolume: ramp.to, timeRange: ramp.range)
            }
            return parameters
        }
        return TransitionComposition(composition: composition, videoComposition: videoComposition, audioMix: audioMix)
    }
}
