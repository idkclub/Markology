import XCTest

class UITests: XCTestCase {
    var app: XCUIApplication!
    private let template: [String: String] = [
        "1613951724.md": """
        # What is this?

        An opionated, [Zettelkasten](/1613965013.md)-inspired note creation and linking tool.

        ## Supports:

        - [Markdown](/1613952665.md) (via [Down](https://github.com/johnxnguyen/Down)).
        - Offline usage and search (via [GRDB](https://github.com/groue/GRDB.swift)).
        - iCloud syncing.

        ## Why?

        - To recall a concept, while only remembering what it related to.
        - To organize thoughts, without needing a heirarchy.
        - To create and discover interesting connections.
        - To track new knowledge, in a way that makes it easy to build on.
        """,
        "1613965013.md": "Zettelkasten",
        "1613965047.md": "# idk Club\n[Markology](/1613951724.md)",
        "1613975039.md": "To File",
        "1613981442.md": "Arcologies",
        "1613952665.md": "Markdown",
        "1614046680.md": "UIKit vs Swift",
        "1608879969.md": "📝 Ideas",
        "1608879702.md": "Movies",
        "1607337187.md": "🍸 Recipes",
    ]

    lazy var directory: URL = {
        let notes = FileManager.default.temporaryDirectory.resolvingSymlinksInPath()
        for file in try! FileManager.default.contentsOfDirectory(atPath: notes.path) {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: file))
        }
        for file in template.keys.sorted() {
            try! template[file]!.write(to: notes.appendingPathComponent(file), atomically: true, encoding: .utf8)
        }
        return notes
    }()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["MARKOLOGY_DIR"] = directory.path
        app.launch()
    }

    func testScreens() throws {
        let windowsQuery = XCUIApplication()/*@START_MENU_TOKEN@*/ .windows/*[[".groups.windows",".windows"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        sleep(4)
        shoot(name: "0-initial")
        windowsQuery.tables.staticTexts["What is this?"].tap()
        sleep(2)
        shoot(name: "1-view")
        windowsQuery.navigationBars["What is this?"].buttons["edit"].tap()
        sleep(2)
        shoot(name: "2-edit")
        app.toolbars["Toolbar"].buttons["Cancel"].tap()
        #if targetEnvironment(simulator)
            windowsQuery.navigationBars["What is this?"].buttons["Markology"].tap()
            sleep(2)
            shoot(name: "3-menu")
        #endif
    }

    private func shoot(name: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
