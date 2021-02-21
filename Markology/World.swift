import Combine
import Down
import Foundation
import GRDB
import Utils

class World {
    static let shared = World()
    let loadingProgress = CurrentValueSubject<Float, Never>(1)
    let db: DatabaseWriter
    var syncing = false
    private var query: NSMetadataQuery?

    init() {
        do {
            let cache = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            ).appendingPathComponent("club.idk.note.db")
            #if DEBUG_SQL
                var config = Configuration()
                config.prepareDatabase { db in
                    db.trace { print($0) }
                }
                dbWriter = try DatabasePool(path: cache.path, configuration: config)
            #else
                db = try DatabasePool(path: cache.path)
            #endif
        } catch {
            db = DatabaseQueue()
        }
        try? migrate()
        sync()
    }

    func migrate() throws {
        var migrator = DatabaseMigrator()
        migrator.eraseDatabaseOnSchemaChange = true
        migrator.registerMigration("v0") { db in
            try db.create(table: "note") { t in
                t.column("file", .text).primaryKey(onConflict: .replace)
                t.column("name", .text)
                t.column("text", .text)
                t.column("modified", .datetime)
                t.column("binary", .boolean)
            }
            try db.create(table: "link") { t in
                t.column("from", .text).references("note", onDelete: .cascade)
                t.column("to", .text).references("note", onDelete: .cascade)
                t.uniqueKey(["from", "to"], onConflict: .ignore)
            }
        }
        try migrator.migrate(db)
    }

    private let fileKeys: [URLResourceKey] = [
        .contentModificationDateKey,
        .isDirectoryKey,
    ]

    func sync(force: Bool = false) {
        DispatchQueue.global(qos: .background).async {
            do {
                try self.syncSync(force: force)
            } catch {
                print(error)
            }
        }
        if Container.icloud, query == nil {
            query = NSMetadataQuery()
            guard let bound = query else { return }
            bound.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            bound.predicate = NSPredicate(value: true)
            NotificationCenter.default.addObserver(forName: NSNotification.Name.NSMetadataQueryDidUpdate, object: query, queue: bound.operationQueue) { [weak self] _ in
                self?.sync()
            }
            bound.enableUpdates()
            bound.start()
        } else if !Container.icloud, query != nil {
            query?.stop()
            query = nil
        }
    }

    func syncSync(force: Bool = false) throws {
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }
        let synced = try db.read { try Note.modified(db: $0) }
        let total = Float(max(synced.count, (try? FileManager.default.contentsOfDirectory(at: Container.current, includingPropertiesForKeys: []).count) ?? 0))
        guard let notes = FileManager.default.enumerator(at: Container.current, includingPropertiesForKeys: fileKeys) else { return }
        _ = try db.write { db in
            var seen: [String] = []
            var links: [Note.Link] = []
            try notes.forEach {
                defer {
                    let progress = Float(seen.count) / total
                    if abs(progress - loadingProgress.value) > 0.1 {
                        loadingProgress.value = progress
                    }
                }
                guard let path = $0 as? URL else { return }
                guard let attrs = try? path.resourceValues(forKeys: Set(fileKeys)),
                      let dir = attrs.isDirectory, !dir,
                      let date = attrs.contentModificationDate else { return }
                if path.pathComponents.contains(where: { $0.first == "." }) {
                    if path.pathExtension == "icloud" {
                        let missing = String(path.deletingLastPathComponent().path.dropFirst(Container.current.path.count) + "/" + path.lastPathComponent.dropLast(7).dropFirst())
                        try FileManager.default.startDownloadingUbiquitousItem(at: Container.url(for: missing))
                        seen.append(missing)
                    }
                    return
                }
                let local = Container.local(for: path)
                seen.append(local)
                if !force, let last = synced[local], Calendar.current.compare(last, to: date, toGranularity: .second) == .orderedSame { return }
                var nsError: NSError?
                NSFileCoordinator().coordinate(readingItemAt: path, error: &nsError) { path in
                    do {
                        guard let text = try? String(contentsOf: path) else {
                            try Note(file: local, name: String(local.dropFirst(1)), text: "", modified: date, binary: true).save(db)
                            return
                        }
                        guard path.markdown else {
                            try Note(file: local, name: String(local.dropFirst(1)), text: text, modified: date, binary: false).save(db)
                            return
                        }
                        let document = try Down(markdownString: text).toDocument()
                        let name = document.name()
                        try Note(
                            file: local,
                            name: name != "" ? name : String(local.dropFirst(1)),
                            text: text,
                            modified: date,
                            binary: false
                        ).save(db)
                        try Note.Link.filter(Note.Link.Columns.from == local).deleteAll(db)
                        for link in document.links(relative: true, includeImage: true) {
                            guard let relative = URL(
                                string: link,
                                relativeTo: URL(string: local)
                            ) else { continue }
                            links.append(Note.Link(
                                from: local,
                                to: relative.path
                            ))
                        }
                    } catch {
                        print("sync fail", error)
                    }
                }
            }
            try Note.filter(!seen.contains(Note.Columns.file)).deleteAll(db)
            for link in links {
                try? link.insert(db)
            }
        }
        loadingProgress.send(1)
    }

    private func open(url: URL, for operation: (URL) throws -> Void) {
        var nsError: NSError?
        var swiftError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, error: &nsError) { url in
            do {
                try operation(url)
            } catch {
                swiftError = error
            }
        }
        if let error = nsError { print(error) }
        if let error = swiftError { print(error) }
        sync()
    }

    func write(contents: String, to url: URL) {
        open(url: url) {
            try FileManager.default.createDirectory(atPath: $0.deletingLastPathComponent().path, withIntermediateDirectories: true, attributes: nil)
            try contents.write(to: $0, atomically: true, encoding: .utf8)
        }
    }

    func delete(url: URL) {
        open(url: url) {
            try FileManager.default.removeItem(at: $0)
        }
    }
}
