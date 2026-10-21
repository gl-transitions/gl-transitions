import Combine
import GLTransitions
import MetalKit
import SwiftUI

/// Each image stays for `hold` seconds, then the transition to the next one plays for `duration`
/// seconds, in a loop. Only the views that show the progress observe it.
@MainActor
final class Clock: ObservableObject {
    static let hold: Float = 1
    static let duration: Float = 1.5

    @Published var playing = true
    @Published private(set) var time: Float = 0
    @Published private(set) var image = 0

    var progress: Float {
        get { min(max((time - Self.hold) / Self.duration, 0), 1) }
        set {
            time = Self.hold + newValue * Self.duration
            playing = false
        }
    }

    func advance(by seconds: Float, imageCount: Int) {
        guard playing else { return }
        time += seconds
        if time >= Self.hold + Self.duration {
            time -= Self.hold + Self.duration
            image = (image + 1) % imageCount
        }
    }
}

/// An MTKView that draws the transition at the clock's progress: on each frame while the clock
/// plays, on each change while it is paused.
@MainActor
struct TransitionView {
    let transition: GLTransition
    let params: [String: ParamValue]
    let preview: PreviewRenderer
    let clock: Clock
    let imageCount: Int
    /// Called when the transition can't be drawn; it isn't drawn again until it or its parameters change.
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(preview: preview, clock: clock, imageCount: imageCount)
    }

    private func makeView(_ coordinator: Coordinator) -> MTKView {
        let view = MTKView(frame: .zero, device: preview.renderer.device)
        view.colorPixelFormat = .bgra8Unorm
        view.delegate = coordinator
        coordinator.attach(view)
        return view
    }

    private func update(_ coordinator: Coordinator) {
        coordinator.onError = onError
        coordinator.show(transition, params: params)
    }

    @MainActor
    final class Coordinator: NSObject, MTKViewDelegate {
        let preview: PreviewRenderer
        let clock: Clock
        let imageCount: Int
        var onError: (String) -> Void = { _ in }
        private var transition: GLTransition?
        private var params: [String: ParamValue] = [:]
        private var failed = false
        private var lastFrame: CFTimeInterval?
        private weak var view: MTKView?
        private var subscriptions: Set<AnyCancellable> = []

        init(preview: PreviewRenderer, clock: Clock, imageCount: Int) {
            self.preview = preview
            self.clock = clock
            self.imageCount = imageCount
        }

        func attach(_ view: MTKView) {
            self.view = view
            view.enableSetNeedsDisplay = true
            clock.$playing.sink { [weak self] playing in
                self?.view?.isPaused = !playing
                self?.lastFrame = nil
            }
            .store(in: &subscriptions)
            clock.$time.sink { [weak self] _ in self?.redrawIfPaused() }.store(in: &subscriptions)
        }

        func show(_ transition: GLTransition, params: [String: ParamValue]) {
            guard transition != self.transition || params != self.params else { return }
            self.transition = transition
            self.params = params
            failed = false
            redrawIfPaused()
        }

        private func redrawIfPaused() {
            guard let view, view.isPaused else { return }
            #if os(macOS)
            view.needsDisplay = true
            #else
            view.setNeedsDisplay()
            #endif
        }

        func mtkView(_: MTKView, drawableSizeWillChange _: CGSize) {
            redrawIfPaused()
        }

        func draw(in view: MTKView) {
            let now = CACurrentMediaTime()
            clock.advance(by: Float(min(now - (lastFrame ?? now), 0.1)), imageCount: imageCount)
            lastFrame = now
            guard let transition, !failed, let drawable = view.currentDrawable,
                  let commandBuffer = preview.commandQueue.makeCommandBuffer()
            else { return }
            do {
                try preview.encode(
                    transition, params: params, image: clock.image, progress: clock.progress,
                    into: drawable.texture, commandBuffer: commandBuffer
                )
            } catch {
                failed = true
                let message = "\(transition.name): \(error)"
                DispatchQueue.main.async { [onError] in onError(message) }
                // Not the previous transition's frame.
                if let pass = view.currentRenderPassDescriptor {
                    pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
                    commandBuffer.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
                }
            }
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }
}

#if os(macOS)
extension TransitionView: NSViewRepresentable {
    func makeNSView(context: Context) -> MTKView {
        makeView(context.coordinator)
    }

    func updateNSView(_: MTKView, context: Context) {
        update(context.coordinator)
    }
}
#else
extension TransitionView: UIViewRepresentable {
    func makeUIView(context: Context) -> MTKView {
        makeView(context.coordinator)
    }

    func updateUIView(_: MTKView, context: Context) {
        update(context.coordinator)
    }
}
#endif
