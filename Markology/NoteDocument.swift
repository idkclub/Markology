import Paths
import UIKit

class NoteDocument: UIDocument {
    enum NoteError: Error {
        case encoding
    }

    var name: File.Name
    var text: String = ""

    init(name: File.Name) {
        self.name = name
        super.init(fileURL: name.url)
    }

    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        guard let data = contents as? Data,
              let text = String(data: data, encoding: .utf8) else { throw NoteError.encoding }
        self.text = text.replacingOccurrences(of: "\r\n", with: "\n")
    }

    override func contents(forType typeName: String) throws -> Any {
        guard let data = text.data(using: .utf8) else { throw NoteError.encoding }
        return data
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
