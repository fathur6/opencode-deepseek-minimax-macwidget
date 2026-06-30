import XCTest
import SwiftUI
@testable import OpencodeWidgetApp

final class PreferencesViewTests: XCTestCase {
    func testInitializes() {
        let view = PreferencesView()
        XCTAssertNotNil(view)
    }
}

final class ContentViewTests: XCTestCase {
    func testInitializes() {
        let view = ContentView()
        XCTAssertNotNil(view)
    }

    @MainActor
    func testHasExpectedButtons() throws {
        let view = ContentView()
        let hostingView = NSHostingView(rootView: view)
        hostingView.setFrameSize(NSSize(width: 200, height: 200))
        hostingView.layout()

        let bodyDesc = String(describing: view.body)
        XCTAssertTrue(bodyDesc.contains("Preferences..."))
        XCTAssertTrue(bodyDesc.contains("Refresh Widget Data"))
        XCTAssertTrue(bodyDesc.contains("Quit"))
    }
}
