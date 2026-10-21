import GLTransitionsExample
import SwiftUI

@main
struct ExampleApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    #endif

    var body: some Scene {
        WindowGroup("gl-transitions") {
            ContentView()
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 760)
        #endif
    }
}

#if os(macOS)
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Started by `swift run`, the executable is not an app bundle: make it a regular app, in front.
    func applicationDidFinishLaunching(_: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        true
    }
}
#endif
