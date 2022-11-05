import GRDB

public extension FTS5TokenizerDescriptor {
    func parse(query: String) -> FTS5Pattern? {
        guard !query.isEmpty else { return nil }
        return (try? DatabaseQueue().inDatabase { db in
            let tokens = try db.makeTokenizer(self).tokenize(query: query).compactMap {
                $0.flags.contains(.colocated) ? nil : $0.token
            }
            try db.create(virtualTable: "document", using: FTS5()) { t in
                t.column("__grdb__")
            }
            return try db.makeFTS5Pattern(rawPattern: tokens.map { "\"\($0)\"*" }.joined(separator: " "), forTable: "document")
        })
    }
}
