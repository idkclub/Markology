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
        let text: String

        public func fetch(db: Database) throws -> [Note] {
            if let pattern = FTS5Pattern(matchingAllPrefixesIn: text) {
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
}

public extension Note {
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
        public let to: [Link]
        public let from: [Link]

        public subscript<T>(dynamicMember keyPath: KeyPath<Note, T>) -> T {
            note[keyPath: keyPath]
        }

        public struct Load: Query {
            let id: ID

            public func fetch(db: Database) throws -> Entry? {
                try Entry.fetchOne(db, Entry.query.filter(key: id.file))
            }
        }
        
        public static func load(id: ID) -> Load {
            Load(id: id)
        }

        public struct Link: Codable, Equatable {
            public let text: String
            public let note: ID
        }
    }
}

public extension Note {
    struct ID: Codable, Equatable, FetchableRecord {
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
            var pattern: FTS5Pattern?
            let limit: Int
            let text: String

            init(text: String, limit: Int) {
                self.text = text
                self.limit = limit
//                pattern = Engine.shared.tokenize(query: text)
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
                order by \(searchRank)
                limit ?
                """, arguments: [pattern, limit])
            }
        }
        
        public static func search(text: String, limit: Int = 10) -> Search {
            Search(text: text, limit: limit)
        }
    }
}

public extension Note.ID.Search? {
    var valid: Bool { self?.pattern != nil }
}

public extension Note {
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

        let from: File.Name
        let to: File.Name
        let text: String
        
        public init(from: String, to: String, text: String) {
            self.from = from
            self.to = to
            self.text = text
        }
        
        public static func deleteAll(db: Database, in froms: [String]) throws {
            try Note.Link.filter(froms.contains(Note.Link.Columns.from)).deleteAll(db)
        }
        
        public static func deleteAll(db: Database, excluding froms: [String]) throws {
            try Note.Link.filter(!froms.contains(Note.Link.Columns.from)).deleteAll(db)
        }
    }
}
