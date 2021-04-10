import Foundation
import GRDB
import UIKit

struct Reference: Codable, Equatable, FetchableRecord {
    static let query = Note.select(Note.Columns.file, Note.Columns.name)

    let file: String
    let name: String
}

extension World {
    func search(query: String, recent: Bool = true, limit: Int = 10, onChange: @escaping ([Reference]) -> Void) -> DatabaseCancellable {
        ValueObservation.tracking { db -> [Reference] in
            let wildcard = "%\(query.replacingOccurrences(of: " ", with: "%"))%"
            var request = Reference.query.filter(Note.Columns.name.like(wildcard))
            if recent {
                request = request.order(Note.Columns.modified.desc).limit(limit)
            } else {
                request = request.order(Note.Columns.name.asc)
            }
            return try Reference.fetchAll(db, request)
        }.start(in: db, onError: { _ in }, onChange: onChange)
    }

    func connections(of refs: [Reference], excluding: [Reference] = []) -> [Reference] {
        let files = refs.map { $0.file }
        let exclusions = excluding.map { $0.file }
        let request = Reference.query.filter(!exclusions.contains(Note.Columns.file)).having(
            !Note.to.filter(keys: files).isEmpty || !Note.from.filter(keys: files).isEmpty
        ).distinct().order(Note.Columns.name)
        return try! db.read { try Reference.fetchAll($0, request) }
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

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            accessoryView = UIImageView(image: UIImage(systemName: "chevron.forward"))
            accessoryView?.tintColor = .secondaryLabel
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func render(name: String) {
            let empty = name == ""
            textLabel?.text = empty ? "Empty Note" : name
            textLabel?.textColor = empty ? .placeholderText : .label
        }
    }
}
