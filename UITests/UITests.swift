import XCTest

class UITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        #if targetEnvironment(simulator)
            if UIDevice.current.userInterfaceIdiom == .pad {
                XCUIDevice.shared.orientation = .landscapeLeft
            }
        #endif
        app = XCUIApplication()
        app.launchEnvironment["MARKOLOGY_DIR"] = Bundle(for: type(of: self)).path(forResource: "Notes", ofType: "")
        app.launch()
    }

    func testScreens() throws {
        let windowsQuery = XCUIApplication()/*@START_MENU_TOKEN@*/ .windows/*[[".groups.windows",".windows"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        sleep(3)
        shoot(name: "0-initial")
        windowsQuery.tables.staticTexts["Overview"].tap()
        sleep(1)
        shoot(name: "1-view")
        windowsQuery.navigationBars["Overview"].buttons["edit"].tap()
        sleep(1)
        shoot(name: "2-edit")
        windowsQuery.buttons["Add Link"].tap()
        sleep(1)
        shoot(name: "3-link")
    }

    private func shoot(name: String) {
        #if targetEnvironment(macCatalyst)
            let screenshot = app.windows.firstMatch.screenshot()
        #else
            let screenshot = XCUIScreen.main.screenshot()
        #endif
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
