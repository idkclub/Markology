import Combine
import Foundation
import GRDB
import GRDBPlus
import Markdown
import Notes
import Paths

@dynamicMemberLookup
class Engine {
    static let bundle = Bundle.main.bundleIdentifier!
    static let shared = try! Engine()
    let progress = CurrentValueSubject<Float, Never>(1)
    let errors = PassthroughSubject<Error, Never>()
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
        try Note.migrate(db: db)
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
            .sink(receiveCompletion: {
                if case let .failure(err) = $0 {
                    errors.send(err)
                }
            }, receiveValue: action)
    }
}

extension Engine: Monitor {
    func sync(files: [File]) {
        try? db.write {
            let names = files.map { $0.name }
            try Note.deleteAll(db: $0, excluding: names)
            try Link.deleteAll(db: $0, excluding: names)
        }
        update(files: files)
    }

    func update(files: [File]) {
        let times = try? db.read { try Note.lastModified(db: $0) }
        var completed: Float = 0.0
        for file in files {
            defer {
                DispatchQueue.main.async {
                    completed += 1
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
            if file.name.isMarkdown {
                var name = file.name
                if let related = name.related {
                    name = related
                }
                var error: NSError?
                NSFileCoordinator().coordinate(readingItemAt: file.url, error: &error) {
                    guard let text = try? String(contentsOf: $0).replacingOccurrences(of: "\r\n", with: "\n") else { return }
                    update(file: name, with: text, at: modified)
                }
                if let error = error {
                    errors.send(error)
                }
                continue
            }
            try? db.write { db in
                try Note(file: file.name, name: String(file.name.dropFirst()), text: "", modified: modified).insert(db, onConflict: .ignore)
            }
        }
    }

    func delete(files: [File]) {
        try? db.write {
            let names = files.map { $0.name }
            try Note.deleteAll(db: $0, in: names)
            try Link.deleteAll(db: $0, in: names)
        }
    }

    func update(file name: File.Name, with text: String, at modified: Date = Date()) {
        let doc = Document(parsing: text)
        var walk = NoteWalker(from: name)
        walk.visit(doc)
        try? db.write { db in
            try Link.deleteAll(db: db, in: [name])
            try Note(file: name, name: walk.name, text: text, modified: modified).save(db)
            try walk.links.forEach { try $0.save(db) }
        }
    }
}

extension Engine {
    struct NoteWalker: MarkupWalker {
        var from: File.Name
        var context = ""
        var fallback = ""
        var header = ""
        var links: [Notes.Link] = []

        var name: String {
            if header != "" {
                return header
            }
            if fallback != "" {
                return fallback
            }
            return String(from.dropFirst())
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
                  let to = from.use(for: destination)?.removingPercentEncoding else { return }
            links.append(Link(from: from, to: to, text: context))
        }

        mutating func visitImage(_ image: Image) {
            guard let source = image.source,
                  !image.absolute,
                  let to = from.use(for: source)?.removingPercentEncoding else { return }
            links.append(Link(from: from, to: to, text: context))
        }

        mutating func visitParagraph(_ paragraph: Paragraph) {
            context = paragraph.plainText
            defaultVisit(paragraph)
            guard fallback == "" else { return }
            fallback = context
        }
    }
}

extension File.Name {
    var url: URL {
        Engine.paths.locate(file: self).url
    }

    var related: File.Name? {
        let related = String(dropLast(3))
        if FileManager.default.fileExists(atPath: related.url.path) {
            return related
        }
        return nil
    }

    var isMarkdown: Bool {
        hasSuffix(".md")
    }

    var markdown: Self {
        isMarkdown ? self : appending(".md")
    }
}
