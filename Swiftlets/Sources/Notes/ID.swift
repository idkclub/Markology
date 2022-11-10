import Foundation
import GRDB
import GRDBPlus
import Paths

public struct ID: Codable, Equatable, Hashable, FetchableRecord {
    static let query = Note.select(Note.Columns.file, Note.Columns.name)

    public let file: File.Name
    public let name: String

    public init(file: File.Name, name: String) {
        self.file = file.decomposedStringWithCanonicalMapping
        self.name = name
    }

    public static func generate(for name: String) -> ID {
        ID(file: "/\(Int(Date().timeIntervalSince1970).description).md", name: name)
    }

    public static func exists(db: Database, file: String) throws -> Bool {
        try ID.query.filter(key: file).fetchCount(db) > 0
    }

    public struct Search: Query {
        public var text: String {
            didSet {
                pattern = Note.tokenizer.parse(query: text)
            }
        }

        var limit: Int
        public mutating func toggleLimit() {
            limit = -limit
        }

        var pattern: FTS5Pattern?

        public func fetch(db: Database) throws -> [ID] {
            guard let pattern = pattern else {
                return try ID.fetchAll(db, limit > 0 ?
                    ID.query.order(Note.Columns.modified.desc).limit(limit) :
                    ID.query.order(Note.Columns.name.asc))
            }
            return try ID.fetchAll(db, sql: """
            select note.file, note.name from note
            join note_search on note.rowid = note_search.rowid
                and note_search match ?
            order by \(Note.searchRank)
            limit ?
            """, arguments: [pattern, limit])
        }
    }

    public static func search(text: String, limit: Int = 10) -> Search {
        Search(text: text, limit: limit, pattern: Note.tokenizer.parse(query: text))
    }
}

public extension ID.Search? {
    var valid: Bool { self?.pattern != nil }
    var limited: Bool { self?.limit ?? 1 > 0 }
}

public extension ID {
    struct Connection: Codable, Hashable, FetchableRecord {
        public let id: ID
        public let from: [ID]
        public let to: [ID]
    }

    static func connections(db: Database, of sources: [ID], excluding: [ID]) throws -> [Connection] {
        let files = sources.map { $0.file }
        let exclusions = files + excluding.map { $0.file }
        return try Connection.fetchAll(
            db,
            ID.query.filter(
                Note.filter(!exclusions.contains(Note.Columns.file))
                    .having(!Note.from.filter(files.contains(Link.Columns.from)).isEmpty || !Note.to.filter(files.contains(Link.Columns.to)).isEmpty)
                    .select(Note.Columns.file)
                    .contains(Note.Columns.file))
                .including(all: Note.toNote.selectID.filter(keys: files).distinct().order(Note.Columns.name.asc).forKey("to"))
                .including(all: Note.fromNote.selectID.filter(keys: files).distinct().order(Note.Columns.name.asc).forKey("from"))
                .order(Note.Columns.name.asc)
        )
    }
}

extension HasManyThroughAssociation<Note, BelongsToAssociation<Link, Note>.RowDecoder> {
    var selectID: Self {
        select(Note.Columns.file, Note.Columns.name)
    }
}
