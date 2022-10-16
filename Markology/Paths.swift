import Combine
import Foundation

class Paths {
    private static let disableKey = "paths.icloud.disable"
    private let id: String
    private let defaults: UserDefaults

    let busy = CurrentValueSubject<Bool, Never>(false)

    var icloud: Bool = false {
        didSet {
            defaults.set(!icloud, forKey: Paths.disableKey)
            reset()
        }
    }

    var documents: URL!

    init(for id: String) {
        self.id = id
        defaults = UserDefaults(suiteName: "group.\(id)")!
        icloud = !defaults.bool(forKey: Paths.disableKey) && icloudAvailable
        reset()
    }

    // TODO: Monitor changes.
    var icloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private var localURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    // TODO: Use in appex contexts.
    private var groupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.\(id)")?.appendingPathComponent("Documents").resolvingSymlinksInPath()
    }

    private var icloudURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.\(id)")?.appendingPathComponent("Documents").resolvingSymlinksInPath()
    }

    var monitor: Monitor? {
        didSet {
            reset()
        }
    }

    private var metadataQuery: NSMetadataQuery?
    private var fileDescriptor: Int32?
    private var objectSource: DispatchSourceFileSystemObject?

    private func reset() {
        documents = icloud ? icloudURL : localURL
        metadataQuery?.stop()
        metadataQuery = nil
        objectSource?.cancel()
        objectSource = nil
        if let file = fileDescriptor {
            close(file)
            fileDescriptor = nil
        }
        guard monitor != nil else { return }
        if icloud {
            let query = NSMetadataQuery()
            query.operationQueue = OperationQueue()
            query.operationQueue?.maxConcurrentOperationCount = 1
            query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            query.predicate = NSPredicate(value: true)
            NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: query.operationQueue, using: initial)
            NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: query.operationQueue, using: update)
            query.enableUpdates()
            query.start()
            metadataQuery = query
            return
        }
        let file = open(documents.path, O_EVTONLY)
        // TODO: This only monitors the top level folder.
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: file, eventMask: .write, queue: .global())
        source.setEventHandler(handler: local)
        source.resume()
        fileDescriptor = file
        objectSource = source
        local()
    }

    private func local() {
        busy.send(true)
        defer { busy.send(false) }
        guard let monitor = monitor,
              let enumerator = FileManager.default.enumerator(at: documents, includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey, .isHiddenKey]) else { return }
        monitor.sync(files: enumerator.compactMap { File(in: documents, at: $0) })
    }

    private func initial(note: Notification) {
        busy.send(true)
        defer { busy.send(false) }
        guard let query = metadataQuery,
              let monitor = monitor,
              let icloudURL = icloudURL else { return }
        query.disableUpdates()
        if let results = query.results as? [NSMetadataItem] {
            monitor.sync(files: results.compactMap { File(in: icloudURL, from: $0) })
        }
        query.enableUpdates()
    }

    private func update(note: Notification) {
        busy.send(true)
        defer { busy.send(false) }
        guard let monitor = monitor,
              let changed = note.userInfo?["kMDQueryUpdateChangedItems"] as? [NSMetadataItem],
              let deleted = note.userInfo?["kMDQueryUpdateRemovedItems"] as? [NSMetadataItem],
              let icloudURL = icloudURL else { return }
        if changed.count > 0 {
            monitor.update(files: changed.compactMap { File(in: icloudURL, from: $0) })
        }
        if deleted.count > 0 {
            monitor.delete(files: deleted.compactMap { File(in: icloudURL, from: $0) })
        }
    }
}

struct File {
    let url: URL
    let name: String

    init?(in container: URL, from item: NSMetadataItem) {
        guard let url = item.value(forAttribute: NSMetadataItemURLKey) as? URL else { return nil }
        self.url = url.resolvingSymlinksInPath()
        name = String(self.url.path.dropFirst(container.path.count))
    }

    init?(in container: URL, at url: Any) {
        guard let url = url as? URL else { return nil }
        self.url = url.resolvingSymlinksInPath()
        name = String(self.url.path.dropFirst(container.path.count))
    }
}

protocol Monitor {
    func sync(files: [File])
    func update(files: [File])
    func delete(files: [File])
}
