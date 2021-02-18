import Foundation
import GRDB

struct Note: Codable, Equatable, FetchableRecord, PersistableRecord {
    enum Columns {
        static let file = Column(CodingKeys.file)
        static let name = Column(CodingKeys.name)
        static let text = Column(CodingKeys.text)
        static let modified = Column(CodingKeys.modified)
    }

    static let fromLink = hasMany(Link.self, using: Link.toKey).forKey("fromLink")
    static let from = hasMany(
        Note.self,
        through: hasMany(Link.self, using: Link.toKey).forKey("fromJoin"),
        using: Link.from
    ).forKey("from")
    static let toLink = hasMany(Link.self, using: Link.fromKey).forKey("toLink")
    static let to = hasMany(
        Note.self,
        through: hasMany(Link.self, using: Link.fromKey).forKey("toJoin"),
        using: Link.to
    ).forKey("to")

    let file: String
    let name: String
    let text: String
    let modified: Date
    let binary: Bool

    func reference() -> Reference {
        Reference(file: file, name: name)
    }
}

extension Note {
    struct File: Codable, FetchableRecord {
        static let query = Note.select(Note.Columns.file, Note.Columns.modified)
        let file: String
        let modified: Date
    }

    static func modifed(db: Database) throws -> [String: Date] {
        return try File.fetchAll(db, File.query).reduce(into: [:]) {
            $0[$1.file] = $1.modified
        }
    }
}

extension Note {
    struct Link: Codable, FetchableRecord, PersistableRecord {
        enum Columns {
            static let from = Column(CodingKeys.from)
            static let to = Column(CodingKeys.to)
        }

        static let fromKey = ForeignKey([Link.Columns.from])
        static let toKey = ForeignKey([Link.Columns.to])
        static let from = belongsTo(Note.self, using: fromKey)
        static let to = belongsTo(Note.self, using: toKey)

        let from: String
        let to: String
    }
}

extension Note {
    struct Entry: Codable, Equatable, FetchableRecord {
        static let query = Note.all()
            .including(all: Note.to.select(Note.Columns.file, Note.Columns.name))
            .including(all: Note.from.select(Note.Columns.file, Note.Columns.name))
        let note: Note
        let to: [Reference]
        let from: [Reference]
    }
}

extension World {
    func search(query: String, onChange: @escaping ([Note]) -> Void) -> DatabaseCancellable {
        ValueObservation.tracking { db -> [Note] in
            let wildcard = "%\(query.replacingOccurrences(of: " ", with: "%"))%"
            return try Note.filter(Note.Columns.text.like(wildcard) || Note.Columns.name.like(wildcard))
                .order(Note.Columns.modified.desc).fetchAll(db)
        }.start(in: db, onError: { _ in }, onChange: onChange)
    }

    func load(note: Reference, onChange: @escaping (Note.Entry?) -> Void) -> DatabaseCancellable {
        ValueObservation.tracking { db in
            try Note.Entry.fetchOne(db, Note.Entry.query.filter(key: note.file))
        }.start(in: db, onError: { _ in }, onChange: onChange)
    }
}
