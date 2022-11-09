import Foundation
import GRDB
import GRDBPlus
import Paths

public struct ID: Codable, Equatable, Hashable, FetchableRecord {
    static let query = Note.select(Note.Columns.file, Note.Columns.name)

    public let file: File.Name
    public let name: String

    public init(file: File.Name, name: String) {
        self.file = file
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
