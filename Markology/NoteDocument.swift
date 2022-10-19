import UIKit

class NoteDocument: UIDocument {
    var name: Paths.File.Name
    var text: String = ""

    init(name: Paths.File.Name) {
        self.name = name
        super.init(fileURL: name.url)
    }

    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        // TODO: Handle error.
        guard let data = contents as? Data,
              let text = String(data: data, encoding: .utf8) else { return }
        self.text = text.replacingOccurrences(of: "\r\n", with: "\n")
    }

    override func contents(forType typeName: String) throws -> Any {
        // TODO: Handle error.
        text.data(using: .utf8)!
    }
}
