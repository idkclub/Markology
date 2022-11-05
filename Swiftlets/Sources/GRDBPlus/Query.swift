import GRDB

public protocol Query {
    associatedtype Value
    func fetch(db: Database) throws -> Value
}
