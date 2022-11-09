import GRDB
import GRDBPlus
import Paths
import UIKit

public struct Note: Codable, Equatable, FetchableRecord, PersistableRecord {
    enum Columns {
        static let file = Column(CodingKeys.file)
        static let name = Column(CodingKeys.name)
        static let text = Column(CodingKeys.text)
        static let modified = Column(CodingKeys.modified)
    }

    static let tokenizer = FTS5TokenizerDescriptor.unicode61(categories: "L* N* S* Co", tokenCharacters: Set("#"))
    static let searchRank = "round(bm25(note_search, 50)), note.modified desc"
    static let from = hasMany(Link.self, using: Link.toKey).forKey("fromLink")
    static let to = hasMany(Link.self, using: Link.fromKey).forKey("toLink")

    public let file: File.Name
    public let name: String
    public let text: String
    public let modified: Date

    public init(file: File.Name, name: String, text: String, modified: Date) {
        self.file = file
        self.name = name
        self.text = text
        self.modified = modified
    }

    public var id: ID {
        ID(file: file, name: name)
    }

    public static func lastModified(db: Database) throws -> [String: Date] {
        struct FileDate: Codable, FetchableRecord {
            static let query = Note.select(Note.Columns.file, Note.Columns.modified)
            let file: File.Name
            let modified: Date
        }

        return try FileDate.fetchAll(db, FileDate.query).reduce(into: [:]) {
            $0[$1.file] = $1.modified
        }
    }

    public static func deleteAll(db: Database, in names: [String]) throws {
        try Note.filter(names.contains(Note.Columns.file)).deleteAll(db)
    }

    public static func deleteAll(db: Database, excluding names: [String]) throws {
        try Note.filter(!names.contains(Note.Columns.file)).deleteAll(db)
    }

    public struct Search: Query {
        let pattern: FTS5Pattern?
        let text: String

        init(text: String) {
            self.text = text
            pattern = Note.tokenizer.parse(query: text)
        }

        public func fetch(db: Database) throws -> [Note] {
            if let pattern = pattern {
                return try Note.fetchAll(db, sql: """
                select note.* from note
                join note_search on note.rowid = note_search.rowid
                    and note_search match ?
                order by \(searchRank)
                """, arguments: [pattern])
            }
            return try Note.order(Note.Columns.name.asc).fetchAll(db)
        }
    }

    public static func search(text: String) -> Search {
        Search(text: text)
    }

    public static func migrate(db: DatabaseWriter) throws {
        var migrator = DatabaseMigrator()
        migrator.eraseDatabaseOnSchemaChange = true
        migrator.registerMigration("v0") { db in
            try db.create(table: "note") { t in
                t.column("file", .text).primaryKey(onConflict: .replace)
                t.column("name", .text)
                t.column("text", .text)
                t.column("modified", .datetime)
            }
            try db.create(virtualTable: "note_search", using: FTS5()) { t in
                t.synchronize(withTable: "note")
                t.tokenizer = tokenizer
                t.column("name")
                t.column("text")
                t.column("file")
            }
            try db.create(table: "link") { t in
                t.column("from", .text).references("note", onDelete: .cascade)
                t.column("to", .text).references("note")
                t.column("text")
                t.uniqueKey(["from", "to", "text"], onConflict: .ignore)
            }
        }
        try migrator.migrate(db)
    }
}
