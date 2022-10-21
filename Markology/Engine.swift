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
    static let bundle = Bundle.main.bundleIdentifier!
    static let shared = try! Engine()
    let progress = CurrentValueSubject<Float, Never>(1)
    let paths = Paths(for: bundle)
    private let db: DatabaseWriter
    init() throws {
        let cache = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("note.db")
        var config = Configuration()
        config.foreignKeysEnabled = false
        db = try DatabasePool(path: cache.path, configuration: config)
        try migrate()
        paths.monitor = self
    }

    static subscript<T>(dynamicMember keyPath: KeyPath<Engine, T>) -> T {
        shared[keyPath: keyPath]
    }

    static func subscribe<T: Query>(_ action: @escaping (T.Value) -> Void, to query: T) -> AnyCancellable where T.Value: Equatable {
        ValueObservation
            .tracking(query.fetch)
            .removeDuplicates()
            .publisher(in: shared.db, scheduling: .immediate)
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
                // TODO: Consider subclassing similar to porter if can avoid "NES" breaking.
                t.tokenizer = .unicode61(categories: "L* N* S*")
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

extension Engine: Monitor {
    func sync(files: [Paths.File]) {
        try? db.write {
            let names = files.map { $0.name }
            try Note.filter(!names.contains(Note.Columns.file)).deleteAll($0)
            // TODO: Remove if foreign keys enabled.
            try Note.Link.filter(!names.contains(Note.Link.Columns.from)).deleteAll($0)
        }
        update(files: files)
    }

    func update(files: [Paths.File]) {
        let times = try? db.read { try Note.lastModified(db: $0) }
        var completed: Float = 0.0
        for file in files {
            defer {
                completed += 1
                DispatchQueue.main.async {
                    self.progress.value = completed / Float(files.count)
                }
            }
            guard !file.url.pathComponents.contains(where: { $0.hasPrefix(".") }),
                  let attrs = try? file.url.resourceValues(forKeys: [.contentModificationDateKey, .isDirectoryKey, .isHiddenKey]),
                  attrs.isDirectory == false,
                  attrs.isHidden == false,
                  let modified = attrs.contentModificationDate else { continue }
            if let last = times?[file.name],
               Calendar.current.compare(last, to: modified, toGranularity: .second) == .orderedSame { continue }
            if file.url.pathExtension == "md" {
                var error: NSError?
                NSFileCoordinator().coordinate(readingItemAt: file.url, error: &error) {
                    guard let text = try? String(contentsOf: $0).replacingOccurrences(of: "\r\n", with: "\n") else { return }
                    update(file: file.name, with: text, at: modified)
                }
            }
        }
    }

    func delete(files: [Paths.File]) {
        try? db.write {
            let names = files.map { $0.name }
            try Note.filter(names.contains(Note.Columns.file)).deleteAll($0)
            // TODO: Remove if foreign keys enabled.
            try Note.Link.filter(names.contains(Note.Link.Columns.from)).deleteAll($0)
        }
    }

    func update(file name: Paths.File.Name, with text: String, at modified: Date = Date()) {
        let doc = Document(parsing: text)
        var walk = NoteWalker(from: name)
        walk.visit(doc)
        try! db.write { db in
            try Note.Link.filter(Note.Link.Columns.from == name).deleteAll(db)
            try Note(file: name, name: walk.name, text: text, modified: modified).save(db)
            try walk.links.forEach { try $0.save(db) }
        }
    }
}

extension Engine {
    struct NoteWalker: MarkupWalker {
        var from: Paths.File.Name
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
                  !link.absolute,
                  let to = from.use(for: destination) else { return }
            links.append(Note.Link(from: from, to: to, text: context))
        }

        mutating func visitParagraph(_ paragraph: Paragraph) {
            context = paragraph.plainText
            defaultVisit(paragraph)
            guard fallback == "" else { return }
            fallback = context
        }
    }
}

extension Paths.File.Name {
    var url: URL {
        Engine.paths.locate(file: self).url
    }
}
