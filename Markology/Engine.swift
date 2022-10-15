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
        var config = Configuration()
        config.foreignKeysEnabled = false
        db = try DatabasePool(path: cache.path, configuration: config)
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
            .sink(receiveCompletion: {
                print($0)
            }, receiveValue: action)
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
                t.column("text")
                t.uniqueKey(["from", "to", "text"], onConflict: .ignore)
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
            if let last = times?[url.lastPathComponent],
               Calendar.current.compare(last, to: modified, toGranularity: .second) == .orderedSame { continue }
            if url.pathExtension == "md" {
                let coordinator = NSFileCoordinator()
                var error: NSError?
                coordinator.coordinate(readingItemAt: url, error: &error) {
                    guard let text = try? String(contentsOf: $0)
                        .replacingOccurrences(of: "\r\n", with: "\n") else { return }
                    let file = url.lastPathComponent
                    let doc = Document(parsing: text)
                    var walk = NoteWalker(file: file)
                    walk.visit(doc)
                    do {
                        try db.write { db in
                            try Note.Link.filter(Note.Link.Columns.from == file).deleteAll(db)
                            try Note(file: file, name: walk.name, text: text, modified: modified).save(db)
                            try walk.links.forEach { try $0.save(db) }
                        }
                    } catch {
                        print(error)
                    }
                }
            }
        }
    }

    struct NoteWalker: MarkupWalker {
        var file: String
        var context = ""
        var fallback = ""
        var header = ""
        var links: [Note.Link] = []

        var name: String {
            if header != "" {
                return header
            }
            return fallback
        }

        mutating func visitHeading(_ heading: Heading) {
            context = heading.plainText
            defaultVisit(heading)
            guard header == "" else { return }
            header = context
        }

        mutating func visitLink(_ link: Markdown.Link) {
            guard let destination = link.destination,
                  !destination.contains(":"),
                  !destination.contains("//"),
                  let to = URL(string: destination)?.lastPathComponent else { return }
            links.append(Note.Link(from: file, to: to, text: context))
        }

        mutating func visitParagraph(_ paragraph: Paragraph) {
            context = paragraph.plainText
            defaultVisit(paragraph)
            guard fallback == "" else { return }
            fallback = context
        }
    }
}
