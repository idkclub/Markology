import XCTest

class UITests: XCTestCase {
    var app: XCUIApplication!
    private let template: [String: String] = [
        "1613951724.md": """
# What is this?
        
An opionated, [Zettelkasten](/1613965013.md)-inspired note creation and linking tool.

## Supports:

- [Markdown](/1613952665.md) (via [Down](https://github.com/johnxnguyen/Down))
- Offline usage and search.
- iCloud syncing.
""",
        "1613965013.md": "Zettelkasten",
        "1613965047.md": "# idk Club\n[Markology](/1613951724.md)",
        "1613975039.md": "To File",
        "1613981442.md": "Arcologies",
        "1613952665.md": "Markdown",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        let notes = FileManager.default.temporaryDirectory
        for file in try FileManager.default.contentsOfDirectory(atPath: notes.path) {
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: file))
        }
        print(notes)
        for file in template {
            try file.value.write(to: notes.appendingPathComponent(file.key), atomically: true, encoding: .utf8)
        }
        app = XCUIApplication()
        app.launchEnvironment["MARKOLOGY_DIR"] = notes.path
        app.launch()
    }

    func testScreens() throws {
        let windowsQuery = XCUIApplication()/*@START_MENU_TOKEN@*/.windows/*[[".groups.windows",".windows"],[[[-1,1],[-1,0]]],[0]]@END_MENU_TOKEN@*/
        windowsQuery.tables.staticTexts["Markology"].tap()
        shoot(name: "index")
        windowsQuery.navigationBars["Markology"].buttons["edit"].tap()
        shoot(name: "edit")
    }
    
    private func shoot(name: String) {
        let screenshot = app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
