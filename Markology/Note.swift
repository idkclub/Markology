import GRDB
import Markdown
import UIKit

struct Note: Codable, Equatable, FetchableRecord, PersistableRecord {
    enum Columns {
        static let file = Column(CodingKeys.file)
        static let name = Column(CodingKeys.name)
        static let text = Column(CodingKeys.text)
        static let modified = Column(CodingKeys.modified)
    }

    // TODO: Investigate ordering value for "Movie" case.
    static let search = "bm25(note_search, 50)"
    static let from = hasMany(Link.self, using: Link.toKey).forKey("fromLink")
    static let to = hasMany(Link.self, using: Link.fromKey).forKey("toLink")

    let file: Paths.File.Name
    let name: String
    let text: String
    let modified: Date

    static func lastModified(db: Database) throws -> [String: Date] {
        struct File: Codable, FetchableRecord {
            static let query = Note.select(Note.Columns.file, Note.Columns.modified)
            let file: Paths.File.Name
            let modified: Date
        }

        return try File.fetchAll(db, File.query).reduce(into: [:]) {
            $0[$1.file] = $1.modified
        }
    }

    struct Search: Query {
        let text: String

        func fetch(db: Database) throws -> [Note] {
            if let pattern = FTS5Pattern(matchingAllPrefixesIn: text) {
                return try Note.fetchAll(db, sql: """
                select note.* from note
                join note_search on note.rowid = note_search.rowid
                    and note_search match ?
                order by \(search)
                """, arguments: [pattern])
            }
            return try Note.order(Note.Columns.name.asc).fetchAll(db)
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

        struct Link: Codable, Equatable {
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
    struct ID: Codable, Equatable, FetchableRecord {
        static let query = Note.select(Note.Columns.file, Note.Columns.name)

        let file: Paths.File.Name
        let name: String

        static func generate(for name: String) -> ID {
            ID(file: "/\(Int(Date().timeIntervalSince1970).description).md", name: name)
        }

        struct Search: Query {
            let pattern: FTS5Pattern?
            let limit: Int
            let text: String

            init(text: String, limit: Int = 10) {
                self.text = text
                self.limit = limit
                pattern = FTS5Pattern(matchingAllPrefixesIn: text)
            }

            func fetch(db: Database) throws -> [ID] {
                guard let pattern = pattern else {
                    let request = ID.query.order(Note.Columns.modified.desc).limit(limit)
                    return try ID.fetchAll(db, request)
                }
                return try ID.fetchAll(db, sql: """
                select note.file, note.name from note
                join note_search on note.rowid = note_search.rowid
                    and note_search match ?
                order by \(search)
                limit ?
                """, arguments: [pattern, limit])
            }
        }

        class Cell: UITableViewCell, RenderCell {
            func render(_ text: String) {
                var content = defaultContentConfiguration()
                if text == "" {
                    content.text = "Empty Note"
                    content.textProperties.color = .placeholderText
                } else {
                    content.text = text
                }
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
