import GRDB
import Paths

public struct Link: Codable, Equatable, PersistableRecord {
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
        try Link.filter(froms.contains(Link.Columns.from)).deleteAll(db)
    }

    public static func deleteAll(db: Database, excluding froms: [String]) throws {
        try Link.filter(!froms.contains(Link.Columns.from)).deleteAll(db)
    }
}
