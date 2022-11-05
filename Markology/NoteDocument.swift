import Paths
import UIKit

class NoteDocument: UIDocument {
    var name: File.Name
    var text: String = ""

    init(name: File.Name) {
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

    override func handleError(_ error: Error, userInteractionPermitted: Bool) {
        if userInteractionPermitted {
            Engine.errors.send(error)
        } else {
            print("NoteDocument error:", error)
        }
        super.handleError(error, userInteractionPermitted: userInteractionPermitted)
    }
}
