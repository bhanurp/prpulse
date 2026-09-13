import XCTest
@testable import PRPulseApp

final class SettingsWindowPresenterTests: XCTestCase {
    @MainActor
    func testShowActivatesOpensAndFocusesSettingsWindow() async {
        var events: [String] = []
        let focused = expectation(description: "Settings window is focused")

        SettingsWindowPresenter.show(
            activate: { events.append("activate") },
            open: { events.append("open") },
            focus: {
                events.append("focus")
                focused.fulfill()
            }
        )

        await fulfillment(of: [focused], timeout: 1)
        XCTAssertEqual(events, ["activate", "open", "focus"])
    }
}
