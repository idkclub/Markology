import Foundation
import GRDB
import GRDBPlus
import Paths

public struct ID: Codable, Equatable, FetchableRecord {
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

    public struct Search: Query {
        let pattern: FTS5Pattern?
        let limit: Int
        let text: String

        init(text: String, limit: Int) {
            self.text = text
            self.limit = limit
            pattern = Note.tokenizer.parse(query: text)
        }

        public func fetch(db: Database) throws -> [ID] {
            guard let pattern = pattern else {
                let request = ID.query.order(Note.Columns.modified.desc).limit(limit)
                return try ID.fetchAll(db, request)
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
        Search(text: text, limit: limit)
    }
}

public extension ID.Search? {
    var valid: Bool { self?.pattern != nil }
}
