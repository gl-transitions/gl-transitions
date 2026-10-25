import GLTransitions
import SwiftUI

@MainActor
final class Model: ObservableObject {
    enum Mode: Hashable { case preview, video }

    @Published var transition = GLTransitions.named("CrossWarp") ?? GLTransitions.all[0] {
        didSet { if transition != oldValue { params = [:] } }
    }

    /// The parameters changed from their defaults.
    @Published var params: [String: ParamValue] = [:] {
        didSet { previewError = nil }
    }

    @Published var mode = Mode.preview
    @Published var previewError: String?
    let setup: Result<(samples: Samples, preview: PreviewRenderer), Error>
    private var clips: Task<[URL], Error>?

    init() {
        setup = Result {
            let samples = try Samples.load()
            return (samples, try PreviewRenderer(samples: samples))
        }
    }

    /// The clips of the Video mode, made once.
    func clips(_ samples: Samples) -> Task<[URL], Error> {
        if let clips { return clips }
        let task = Task { try await Video.makeClips(samples) }
        clips = task
        return task
    }
}

/// The transitions of the Swift package: pick one, play it between the sample images or between
/// video clips, pause, scrub, tune its parameters.
public struct ContentView: View {
    @StateObject private var model = Model()
    // Not observed: only the playback controls and the preview follow it.
    @State private var clock = Clock()

    public init() {}

    public var body: some View {
        NavigationSplitView {
            TransitionList(selection: $model.transition)
                .navigationTitle("gl-transitions")
                .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            switch model.setup {
            case let .success((samples, preview)):
                detail(samples, preview)
            case let .failure(error):
                Text(String(describing: error)).foregroundStyle(.red).padding()
            }
        }
    }

    private func detail(_ samples: Samples, _ preview: PreviewRenderer) -> some View {
        let transition = model.transition
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Mode", selection: $model.mode) {
                    Text("Preview").tag(Model.Mode.preview)
                    Text("Video").tag(Model.Mode.video)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Group {
                    switch model.mode {
                    case .preview:
                        TransitionView(
                            transition: transition, params: model.params, preview: preview,
                            clock: clock, imageCount: samples.images.count,
                            onError: { error in if model.transition == transition { model.previewError = error } }
                        )
                        .overlay {
                            if let error = model.previewError { Text(error).foregroundStyle(.red).padding() }
                        }
                    case .video:
                        VideoPreview(transition: transition, params: model.params, samples: samples, clips: model.clips(samples))
                    }
                }
                .aspectRatio(samples.aspectRatio, contentMode: .fit)

                if model.mode == .preview { PlaybackControls(clock: clock) }

                VStack(alignment: .leading, spacing: 4) {
                    Text(transition.name).font(.title2.bold())
                    Text(["by \(transition.authorName)", transition.license, transition.description].compactMap { $0 }.joined(separator: " · "))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                ForEach(transition.params, id: \.name) { param in
                    ParamControl(param: param, value: Binding(
                        get: { model.params[param.name] ?? param.defaultValue },
                        set: { model.params[param.name] = $0 }
                    ))
                }
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct PlaybackControls: View {
    @ObservedObject var clock: Clock

    var body: some View {
        HStack {
            Button(clock.playing ? "Pause" : "Play") { clock.playing.toggle() }
                .frame(minWidth: 60)
            Slider(value: $clock.progress, in: 0 ... 1)
        }
    }
}

private struct TransitionList: View {
    @Binding var selection: GLTransition

    var body: some View {
        ScrollViewReader { proxy in
            List(GLTransitions.all, id: \.self, selection: Binding($selection)) { transition in
                HStack {
                    Text(transition.name).layoutPriority(1)
                    Spacer()
                    Text(transition.authorName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
    }
}

extension GLTransition {
    /// Without the email some authors give.
    var authorName: String {
        author.components(separatedBy: " <")[0]
    }
}
