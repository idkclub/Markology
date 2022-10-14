import GRDB
import UIKit

struct Note: Codable, Equatable, FetchableRecord, PersistableRecord, Renderable {
    enum Columns {
        static let file = Column(CodingKeys.file)
        static let name = Column(CodingKeys.name)
        static let text = Column(CodingKeys.text)
        static let modified = Column(CodingKeys.modified)
    }

    let file: String
    let name: String
    let text: String
    let modified: Date

    static func lastModified(db: Database) throws -> [String: Date] {
        struct File: Codable, FetchableRecord {
            static let query = Note.select(Note.Columns.file, Note.Columns.modified)
            let file: String
            let modified: Date
        }

        return try File.fetchAll(db, File.query).reduce(into: [:]) {
            $0[$1.file] = $1.modified
        }
    }

    struct Load: Query {
        let id: ID

        func fetch(db: Database) throws -> Note? {
            try Note.fetchOne(db, key: id.file)
        }
    }
    
    class Cell: UITableViewCell, TableCell {
        lazy var markdown = {
            let markdown = NoteView().pinned(to: contentView)
            markdown.isScrollEnabled = false
            markdown.textContainerInset = .init(top: 15, left: 15, bottom: 15, right: 15)
            return markdown
        }()

        func render(_ note: Note) {
            markdown.note = note
        }
    }
}

extension Note {
    struct ID: Codable, Equatable, FetchableRecord, Renderable {
        static let query = Note.select(Note.Columns.file, Note.Columns.name)

        let file: String
        let name: String

        struct Search: Query {
            let text: String
            let limit: Int = 10
            let recent = true

            func fetch(db: Database) throws -> [ID] {
                let wildcard = "%\(text.replacingOccurrences(of: " ", with: "%"))%"
                var request = ID.query.filter(Note.Columns.name.like(wildcard))
                if recent {
                    request = request.order(Note.Columns.modified.desc).limit(limit)
                } else {
                    request = request.order(Note.Columns.name.asc)
                }
                return try ID.fetchAll(db, request)
            }
        }

        class Cell: UITableViewCell, TableCell {
            func render(_ id: ID) {
                var content = defaultContentConfiguration()
                content.text = id.name
                contentConfiguration = content
            }
        }
    }
}
