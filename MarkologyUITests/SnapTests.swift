import XCTest

final class SnapTests: XCTestCase {
//    override class var runsForEachTargetApplicationUIConfiguration: Bool {
//        true
//    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["PATHS_ICLOUD"] = "0"
        app.launch()
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
        app.links.matching(identifier: "☐").allElementsBoundByIndex.reversed().forEach { $0.tap() }
        snap(app: app)
        app.links.matching(identifier: "personal").firstMatch.tap()
        app.buttons.matching(identifier: "Toggle Editing").firstMatch.tap()
        app.textViews.firstMatch.typeText("""
        > On device, or in iCloud
        Plain text files
        No analytics, no tracking
        """)
        snap(app: app)
        for _ in 1...3 {
            app.navigationBars.buttons.matching(identifier: "more").firstMatch.tap()
            app.buttons.matching(identifier: "Delete Note").firstMatch.tap()
            app.buttons.matching(identifier: "Delete").firstMatch.tap()
        }
        snap(app: app)
    }

    func snap(app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
