import Foundation
import GRDB
import UIKit

struct Reference: Codable, Equatable, FetchableRecord {
    static let query = Note.select(Note.Columns.file, Note.Columns.name)

    let file: String
    let name: String
}

extension World {
    func search(query: String, limit: Int = 10, onChange: @escaping ([Reference]) -> Void) -> DatabaseCancellable {
        ValueObservation.tracking { db -> [Reference] in
            let wildcard = query.replacingOccurrences(of: " ", with: "%")
            let request = Reference.query.filter(Note.Columns.name.like("%\(wildcard)%"))
                .order(Note.Columns.modified.desc).limit(limit)
            return try Reference.fetchAll(db, request)
        }.start(in: db, onError: { _ in }, onChange: onChange)
    }

    func load(file: String) -> Reference? {
        try? db.read {
            try Reference.fetchOne($0, Reference.query.filter(key: file))
        }
    }
}

extension Reference {
    class Cell: UITableViewCell {
        static let id = "reference"

        func render(name: String) {
            let empty = name == ""
            textLabel?.text = empty ? "Empty Note" : name
            textLabel?.textColor = empty ? .placeholderText : .label
        }
    }
}
