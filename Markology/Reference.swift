import Foundation
import GRDB
import UIKit

struct Reference: Codable, Equatable, FetchableRecord {
    static let query = Note.select(Note.Columns.file, Note.Columns.name)

    let file: String
    let name: String
}

extension Reference {
    struct Entry: Codable, Equatable, FetchableRecord {
        var reference: Reference
        let to: [Reference]
        let from: [Reference]
    }
}

extension World {
    func search(query: String, recent: Bool = true, limit: Int = 10, onChange: @escaping ([Reference]) -> Void) -> DatabaseCancellable {
        ValueObservation.tracking { db -> [Reference] in
            let wildcard = "%\(query.replacingOccurrences(of: " ", with: "%"))%"
            var request = Reference.query.filter(Note.Columns.name.like(wildcard))
            if recent {
                request = request.order(Note.Columns.modified.desc).limit(limit)
            } else {
                request = request.order(Note.Columns.name.asc)
            }
            return try Reference.fetchAll(db, request)
        }.start(in: db, onError: { _ in }, onChange: onChange)
    }

    func connections(of refs: [Reference], excluding: [Reference] = []) -> [Reference.Entry] {
        let files = refs.map { $0.file }
        let exclusions = excluding.map { $0.file }
        let request = Reference.query.filter(
            Note.filter(!exclusions.contains(Note.Columns.file))
                .having(!Note.to.filter(keys: files).isEmpty || !Note.from.filter(keys: files).isEmpty)
                .select(Note.Columns.file).contains(Note.Columns.file))
            .including(all: Note.to.select(Note.Columns.file, Note.Columns.name).filter(keys: files).order(Note.Columns.name))
            .including(all: Note.from.select(Note.Columns.file, Note.Columns.name).filter(keys: files).order(Note.Columns.name))
            .order(Note.Columns.name)
        return try! db.read { try Reference.Entry.fetchAll($0, request) }
    }

    func load(file: String) -> Reference? {
        try? db.read {
            try Reference.fetchOne($0, Reference.query.filter(key: file))
        }
    }
}
