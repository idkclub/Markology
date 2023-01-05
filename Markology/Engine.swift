import Combine
import Foundation
import GRDB
import GRDBPlus
import Markdown
import Notes
import NotesUI
import Paths

@dynamicMemberLookup
class Engine: DataSource {
    static let bundle = Bundle.main.bundleIdentifier!
    static let shared = try! Engine()
    let progress = CurrentValueSubject<Float, Never>(1)
    let errors = PassthroughSubject<Error, Never>()
    let paths = Paths(for: bundle)
    let db: DatabaseWriter
    let updatePeriod = DispatchTimeInterval.milliseconds(20)
    init() throws {
        let cache = paths.cached(file: "note.db")!
        var config = Configuration()
        config.foreignKeysEnabled = false
        db = try DatabasePool(path: cache.path, configuration: config)
        try Note.migrate(db: db)
        paths.monitor = self
    }

    static subscript<T>(dynamicMember keyPath: KeyPath<Engine, T>) -> T {
        shared[keyPath: keyPath]
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
        var progressUpdate = DispatchTime.now() + updatePeriod
        try? db.write { db in
            for file in files {
                defer {
                    completed += 1
                    let now = DispatchTime.now()
                    if now > progressUpdate {
                        DispatchQueue.main.async {
                            self.progress.value = completed / Float(files.count)
                        }
                        progressUpdate = now + updatePeriod
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
                        let doc = Document(parsing: text)
                        var walk = NoteWalker(from: name)
                        walk.visit(doc)
                        try? Link.deleteAll(db: db, in: [name])
                        try? Note(file: name, name: walk.name, text: text, modified: modified).save(db)
                        try? walk.links.forEach { try $0.save(db) }
                    }
                    if let error = error {
                        errors.send(error)
                    }
                    continue
                }
                if times?[file.name] != nil { continue }
                try? Note(file: file.name, name: String(file.name.dropFirst()), text: "", modified: modified).insert(db, onConflict: .ignore)
            }
        }
        DispatchQueue.main.async {
            self.progress.value = 1
        }
    }

    func delete(files: [File]) {
        try? db.write {
            let names = files.map { $0.name }
            try Note.deleteAll(db: $0, in: names)
            try Link.deleteAll(db: $0, in: names)
        }
    }
}

extension Engine {
    struct NoteWalker: ContextWalker {
        var from: File.Name
        var context = ""
        var fallback = ""
        var header = ""
        var links: [Notes.Link] = []

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
