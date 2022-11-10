import GRDB
import GRDBPlus

@dynamicMemberLookup
public struct Entry: Codable, Equatable, FetchableRecord {
    static let query = Note.all()
        .including(all: Note.to.select(Notes.Link.Columns.text)
            .including(required: Notes.Link.to.selectID
                .order(Note.Columns.name.asc))
            .forKey("to"))
        .including(all: Note.from.select(Notes.Link.Columns.text)
            .including(required: Notes.Link.from.selectID
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

    public struct Link: Codable, Equatable, Hashable {
        public let text: String
        public let note: ID
    }
}

extension BelongsToAssociation<Link, Note> {
    var selectID: Self {
        select(Note.Columns.file, Note.Columns.name)
    }
}
