import GLTransitions
import SwiftUI
import XCTest

final class SwiftUITests: XCTestCase {
    // SwiftUI has a `Transition` protocol: the package's type must not clash with it.
    func testGLTransitionWithSwiftUI() {
        let transition: GLTransition? = GLTransitions.named("Fade")
        XCTAssertEqual(transition?.name, "Fade")
    }
}
