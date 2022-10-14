import Combine
import Foundation
import GRDB
import Markdown

protocol Query {
    associatedtype Value
    func fetch(db: Database) throws -> Value
}

@dynamicMemberLookup
class Engine {
    static let shared = try! Engine()
    let progress = CurrentValueSubject<Float, Never>(1)
    private let db: DatabaseWriter
    private var query: NSMetadataQuery?
    init() throws {
        let cache = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("club.idk.note.db")
        db = try DatabasePool(path: cache.path)
        try migrate()
        try subscribe()
    }

    static subscript<T>(dynamicMember keyPath: KeyPath<Engine, T>) -> T {
        shared[keyPath: keyPath]
    }

    static func subscribe<T: Query>(_ action: @escaping (T.Value) -> Void, to query: T) -> AnyCancellable where T.Value: Equatable {
        ValueObservation
            .tracking(query.fetch)
            .removeDuplicates()
            .publisher(in: shared.db)
            // TODO: Handle error.
            .sink(receiveCompletion: { _ in }, receiveValue: action)
    }

    private func migrate() throws {
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
                t.tokenizer = .porter(wrapping: .unicode61())
                t.column("file")
                t.column("name")
                t.column("text")
            }
            try db.create(table: "link") { t in
                t.column("from", .text).references("note", onDelete: .cascade)
                t.column("to", .text).references("note")
                t.uniqueKey(["from", "to"], onConflict: .ignore)
            }
        }
        try migrator.migrate(db)
    }

    private func subscribe() throws {
        let query = NSMetadataQuery()
        query.operationQueue = OperationQueue()
        query.operationQueue?.maxConcurrentOperationCount = 1
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(value: true)
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: query.operationQueue, using: initial)
        // TODO: Only process deltas.
        NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: query.operationQueue, using: initial)
        query.enableUpdates()
        query.start()
        self.query = query
    }

    private func initial(note: Notification) {
        guard let query = query else { return }
        query.disableUpdates()
        if let results = query.results as? [NSMetadataItem] {
            sync(urls: results.compactMap {
                $0.value(forAttribute: NSMetadataItemURLKey) as? URL
            })
        }
        query.enableUpdates()
    }

    private func sync(urls: [URL]) {
        let times = try? db.read { try Note.lastModified(db: $0) }
        var completed: Float = 0.0
        for url in urls {
            defer {
                completed += 1
                DispatchQueue.main.async {
                    self.progress.value = completed / Float(urls.count)
                }
            }
            guard !url.pathComponents.contains(where: { $0.hasPrefix(".") }),
                  let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey, .isHiddenKey]),
                  attrs.isDirectory == false,
                  attrs.isHidden == false,
                  let modified = attrs.contentModificationDate else { continue }
            if let last = times?[url.path],
               Calendar.current.compare(last, to: modified, toGranularity: .second) == .orderedSame { continue }
            if url.pathExtension == "md" {
                let coordinator = NSFileCoordinator()
                var error: NSError?
                coordinator.coordinate(readingItemAt: url, error: &error) {
                    guard let text = try? String(contentsOf: $0)
                            .replacingOccurrences(of: "\r\n", with: "\n")else { return }
                    let doc = Document(parsing: text)
                    var walk = NoteWalker()
                    walk.visit(doc)
                    try? db.write {
                        try Note(file: url.path, name: walk.name, text: text, modified: modified).save($0)
                    }
                }
            }
        }
    }

    struct NoteWalker: MarkupWalker {
        var name = ""
        var links: [Markdown.Link] = []
        mutating func visitHeading(_ heading: Heading) {
            if name == "" {
                name = heading.plainText
            }
        }

        mutating func visitLink(_ link: Markdown.Link) {
            links.append(link)
        }
    }
}
