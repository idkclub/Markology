import GRDB
import Markdown
import UIKit

struct Note: Codable, Equatable, FetchableRecord, PersistableRecord, Renderable {
    enum Columns {
        static let file = Column(CodingKeys.file)
        static let name = Column(CodingKeys.name)
        static let text = Column(CodingKeys.text)
        static let modified = Column(CodingKeys.modified)
    }

    static let from = hasMany(Link.self, using: Link.toKey).forKey("fromLink")
    static let to = hasMany(Link.self, using: Link.fromKey).forKey("toLink")

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

    struct Search: Query {
        let query: String

        func fetch(db: Database) throws -> [Note] {
            if let pattern = FTS5Pattern(matchingAllPrefixesIn: query) {
                return try Note.fetchAll(db, sql: """
                select note.* from note
                join note_search on note.rowid = note_search.rowid
                    and note_search match ?
                order by rank
                """, arguments: [pattern])
            }
            return try Note.order(Note.Columns.name.asc).fetchAll(db)
        }
    }

    class Cell: UITableViewCell, TableCell {
        lazy var markdown = {
            let markdown = NoteView().pinned(to: contentView)
            markdown.isScrollEnabled = false
            markdown.isEditable = false
            markdown.textContainerInset = .init(top: 15, left: 15, bottom: 15, right: 15)
            return markdown
        }()

        func render(_ note: Note) {
            let doc = Document(parsing: note.text)
            var visitor = NoteVisitor()
            markdown.attributedText = visitor.visit(doc)
                .setMissing(key: .foregroundColor, value: UIColor.label)
        }
    }
}

extension Note {
    @dynamicMemberLookup
    struct Entry: Codable, Equatable, FetchableRecord {
        static let query = Note.all()
            .including(all: Note.to.select(Note.Link.Columns.text)
                .including(required: Note.Link.to
                    .select(Note.Columns.name, Note.Columns.file)
                    .order(Note.Columns.name.asc))
                .forKey("to"))
            .including(all: Note.from.select(Note.Link.Columns.text)
                .including(required: Note.Link.from
                    .select(Note.Columns.name, Note.Columns.file)
                    .order(Note.Columns.name.asc))
                .forKey("from"))
        let note: Note
        let to: [Link]
        let from: [Link]

        subscript<T>(dynamicMember keyPath: KeyPath<Note, T>) -> T {
            note[keyPath: keyPath]
        }

        struct Load: Query {
            let id: ID

            func fetch(db: Database) throws -> Entry? {
                try Entry.fetchOne(db, Entry.query.filter(key: id.file))
            }
        }

        struct Link: Codable, Equatable, Renderable {
            let text: String
            let note: ID

            class Cell: UITableViewCell, ConfigCell {
                var note = ""

                func config(_ note: String) {
                    self.note = note
                }

                func render(_ link: Note.Entry.Link) {
                    var content = UIListContentConfiguration.valueCell()
                    content.text = link.note.name
                    if link.note.name != link.text,
                       note != link.text
                    {
                        content.secondaryText = link.text
                    }
                    contentConfiguration = content
                }
            }
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

extension Note {
    struct Link: Codable, Equatable, PersistableRecord {
        enum Columns {
            static let from = Column(CodingKeys.from)
            static let to = Column(CodingKeys.to)
            static let text = Column(CodingKeys.text)
        }

        static let fromKey = ForeignKey([Columns.from])
        static let toKey = ForeignKey([Columns.to])
        static let from = belongsTo(Note.self, using: fromKey)
        static let to = belongsTo(Note.self, using: toKey)

        let from: String
        let to: String
        let text: String
    }
}
