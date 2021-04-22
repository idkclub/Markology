import Combine
import Down
import Foundation
import GRDB
import Utils

class World {
    static let shared = World()
    let loadingProgress = CurrentValueSubject<Float, Never>(1)
    let updatePeriod = DispatchTimeInterval.milliseconds(20)
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

    // sync stuff from iCloud (or Documents folder if iCloud disabled) to SQL
    func syncSync(force: Bool = false) throws {
        guard !syncing else { return }
        syncing = true
        defer { syncing = false }

        guard let notes = FileManager.default.enumerator(at: Container.current, includingPropertiesForKeys: fileKeys) else { return }
        let lastSyncedTimes = try db.read { try Note.getAllModifiedTimes(db: $0) }

        let totalFiles = Float(max(lastSyncedTimes.count, (try? FileManager.default.contentsOfDirectory(at: Container.current, includingPropertiesForKeys: []).count) ?? 0))
        var skippingSyncedFiles = true
        var updateAt = DispatchTime.now() + updatePeriod

        _ = try db.write { db in
            var seenFiles: [String] = []
            var linksToSave: [Note.Link] = []
            notes.forEach {
                defer {
                    let now = DispatchTime.now()
                    if !skippingSyncedFiles, now > updateAt {
                        updateAt = now + updatePeriod
                        loadingProgress.value = Float(seenFiles.count) / totalFiles
                    }
                }

                // skip symlinks and directories
                guard let path = ($0 as? URL)?.resolvingSymlinksInPath(),
                      let attrs = try? path.resourceValues(forKeys: Set(fileKeys)),
                      let isDir = attrs.isDirectory, !isDir,
                      let date = attrs.contentModificationDate else { return }

                if path.pathComponents.contains(where: { $0.first == "." }) {
                    if let iCloudPath = checkForICloud(at: path) {
                        seenFiles.append(iCloudPath)
                    }
                    return
                }

                let localPath = Container.local(for: path)
                seenFiles.append(localPath)

                if !force, let last = lastSyncedTimes[localPath], Calendar.current.compare(last, to: date, toGranularity: .second) == .orderedSame { return }
                skippingSyncedFiles = false
                var nsError: NSError?
                NSFileCoordinator().coordinate(readingItemAt: path, error: &nsError) { path in
                    do {
                        guard let document = try saveNote(at: path, with: localPath, in: db, modifiedDate: date) else { return }

                        linksToSave.append(contentsOf: try processLinksForSync(from: document, at: localPath, in: db))
                    } catch {
                        print("sync fail", error)
                    }
                }
                if let error = nsError {
                    print("error reading file", error)
                }
            }

            try Note.filter(!seenFiles.contains(Note.Columns.file)).deleteAll(db)
            for link in linksToSave {
                try? link.insert(db)
            }
        }
        loadingProgress.send(1)
    }

    /**
     Checks if the provided `path` is an iCloud file. If it is, makes sure it is downloaded locally, and returns the canonical file path string.
     */
    private func checkForICloud(at path: URL) -> String? {
        let iCloudExt = "icloud"
        if path.pathExtension == iCloudExt {
            let folderPath = path.deletingLastPathComponent().path.dropFirst(Container.current.path.count)
            let realFile = path.lastPathComponent.dropLast(iCloudExt.count + 1).dropFirst()
            let cloudPath = "\(folderPath)/\(realFile)"
            try? FileManager.default.startDownloadingUbiquitousItem(at: Container.url(for: cloudPath))
            return cloudPath
        }
        return nil
    }

    /**
     Processes a note file at the URL `path` and saves it in the provided `Database`. If the file contains a markdown `Document`, it is returned.
     This function should be called in the context of a database write update, and an `NSFileCoordinator.coordinate` call.
     */
    private func saveNote(at path: URL, with localPath: String, in db: Database, modifiedDate: Date) throws -> Document? {
        let defaultName = String(localPath.dropFirst(1))

        guard let text = try? String(contentsOf: path) else {
            try Note(file: localPath, name: defaultName, text: "", modified: modifiedDate, binary: true).save(db)
            return nil
        }

        guard path.isMarkdown, let document = try? Down(markdownString: text).toDocument() else {
            try Note(file: localPath, name: defaultName, text: text, modified: modifiedDate, binary: false).save(db)
            return nil
        }

        let name = document.name()
        try Note(
            file: localPath,
            name: name != "" ? name : defaultName,
            text: text,
            modified: modifiedDate,
            binary: false
        ).save(db)

        return document
    }

    /**
     Deletes all the old links from the `Document` in the `Database` and returns the current links from the `Document`.
     This function should be called in the context of a database write update.
     */
    private func processLinksForSync(from document: Document, at localPath: String, in db: Database) throws -> [Note.Link] {
        try Note.Link.filter(Note.Link.Columns.from == localPath).deleteAll(db)

        var links: [Note.Link] = []
        for link in document.links(relative: true, includeImage: true) {
            guard let resolvedLink = URL(
                string: link,
                relativeTo: URL(string: localPath)
            ) else { continue }
            links.append(
                Note.Link(from: localPath, to: resolvedLink.path)
            )
        }
        return links
    }

    private func open(url: URL, for operation: (URL) throws -> Void) throws {
        var nsError: NSError?
        var swiftError: Error?
        NSFileCoordinator().coordinate(writingItemAt: url, error: &nsError) { url in
            do {
                try operation(url)
            } catch {
                swiftError = error
            }
        }
        if let error = nsError { throw error }
        if let error = swiftError { throw error }
        sync()
    }

    func write(contents: String, to url: URL) throws {
        try open(url: url) {
            try FileManager.default.createDirectory(atPath: $0.deletingLastPathComponent().path, withIntermediateDirectories: true, attributes: nil)
            try contents.write(to: $0, atomically: true, encoding: .utf8)
        }
    }

    func delete(url: URL) throws {
        try open(url: url) {
            try FileManager.default.removeItem(at: $0)
        }
    }
}
