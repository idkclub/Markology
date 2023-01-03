import XCTest

final class SnapTests: XCTestCase {
    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["PATHS_TEST"] = "1"
        app.launch()
        if !app.staticTexts["Empty Note"].exists {
            app.buttons["ToggleSidebar"].tap()
        }
        app.staticTexts["Empty Note"].tap()
        app.textViews.firstMatch.typeText("This is a Note")
        app.collectionViews.staticTexts["Note"].firstMatch.tap()
        app.links.firstMatch.tap()
        app.textViews.firstMatch.typeText("""
        ## Useful for

        - [ ] Organizing thoughts *without* a heirarchy
        Discovering **connections**
        Carrying a personal
        """)
        app.collectionViews.staticTexts["personal"].firstMatch.tap()
        app.textViews.firstMatch.typeText("""
         `knowledge base` everywhere you go

        ---

        Zettelkästen-inspired, Markdown-powered
        """)
        app.navigationBars.buttons.matching(identifier: "Toggle Editing").firstMatch.tap()
        let checkboxes = app.links.matching(identifier: "☐")
        for _ in 1 ... checkboxes.count {
            checkboxes.firstMatch.tap()
        }
        _ = app.links.matching(identifier: "☑").element(boundBy: 2).waitForExistence(timeout: 0.5)
        snap(app: app, name: "Page 1")
        app.links.matching(identifier: "personal").firstMatch.tap()
        _ = app.navigationBars.staticTexts["personal"].waitForExistence(timeout: 0.5)
        app.buttons.matching(identifier: "Toggle Editing").firstMatch.tap()
        app.textViews.firstMatch.typeText("""
        > On device, or in iCloud
        Plain text files
        No analytics, no tracking
        """)
        snap(app: app, name: "Page 2")
        for _ in 1 ... 3 {
            app.navigationBars.buttons.matching(identifier: "more").firstMatch.tap()
            app.buttons.matching(identifier: "Delete Note").firstMatch.tap()
            app.buttons.matching(identifier: "Delete").firstMatch.tap()
        }
        snap(app: app, name: "Menu")
    }

    func snap(app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.lifetime = .keepAlways
        attachment.name = name
        add(attachment)
    }
}
