import Combine
import Foundation

public class Paths {
    private static let disableKey = "paths.icloud.disable"
    private let id: String
    private let defaults: UserDefaults
    let inExtension: Bool

    public let busy = CurrentValueSubject<Bool, Never>(false)

    public var icloud: Bool = false {
        didSet {
            defaults.set(!icloud, forKey: Paths.disableKey)
            reset()
        }
    }

    public var documents: URL!

    public init(for id: String, inExtension: Bool = false) {
        self.id = id
        self.inExtension = inExtension
        defaults = UserDefaults(suiteName: "group.\(id)")!
        icloud = !defaults.bool(forKey: Paths.disableKey)
        migrate()
        reset()

        NotificationCenter.default.addObserver(forName: .NSUbiquityIdentityDidChange, object: self, queue: .main, using: change)
    }

    public func locate(file: File.Name) -> File {
        File(in: documents, named: file)
    }

    public var icloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private var groupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.\(id)")?.resolvingSymlinksInPath()
    }

    private var groupDocuments: URL? {
        groupURL?.appendingPathComponent("Documents")
    }

    public func cached(file: String) -> URL? {
        groupURL?.appendingPathComponent("Library/Caches").appendingPathComponent(file)
    }

    private var localURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    private var icloudURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.\(id)")?.appendingPathComponent("Documents").resolvingSymlinksInPath()
    }

    public var monitor: Monitor? {
        didSet {
            reset()
        }
    }

    private var metadataQuery: NSMetadataQuery?
    private var fileDescriptor: Int32?
    private var objectSource: DispatchSourceFileSystemObject?

    private func migrate() {
        guard !inExtension,
              let groupDocuments = groupDocuments,
              let enumerator = FileManager.default.enumerator(at: groupDocuments, includingPropertiesForKeys: nil) else { return }
        busy.send(true)
        defer { busy.send(false) }
        enumerator.forEach {
            guard let file = File(in: groupDocuments, at: $0) else { return }
            try? FileManager.default.moveItem(at: file.url, to: localURL!.appendingPathComponent(file.name))
        }
    }

    private func change(_: Notification) {
        reset()
    }

    private func reset() {
        busy.send(true)
        defer { busy.send(false) }
        let icloud = self.icloud && icloudAvailable
        documents = icloud ?
            icloudURL :
            inExtension ? groupDocuments : localURL
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
            query.operationQueue?.qualityOfService = .utility
            query.operationQueue?.maxConcurrentOperationCount = 1
            query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
            query.predicate = NSPredicate(value: true)
            query.notificationBatchingInterval = 0.1
            NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidFinishGathering, object: query, queue: query.operationQueue, using: initial)
            NotificationCenter.default.addObserver(forName: .NSMetadataQueryDidUpdate, object: query, queue: query.operationQueue, using: update)
            query.enableUpdates()
            query.start()
            metadataQuery = query
            return
        }
        let file = open(documents.path, O_EVTONLY)
        // NOTE: This only monitors the top level folder.
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: file, eventMask: .write, queue: .global())
        source.setEventHandler(handler: local)
        source.resume()
        fileDescriptor = file
        objectSource = source
        DispatchQueue.global(qos: .utility).async {
            self.local()
        }
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

public protocol Monitor {
    func sync(files: [File])
    func update(files: [File])
    func delete(files: [File])
}
