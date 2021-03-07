import Foundation

public class Container {
    static let shared = Container()
    public static var icloudEnabled: Bool { FileManager.default.ubiquityIdentityToken != nil }
    public static var current: URL { shared.current }
    public static var icloud: Bool { shared.icloud }

    public static func setCloud(enabled: Bool) throws {
        guard shared.icloud != enabled else { return }
        let destination = enabled ? icloudURL : localURL
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)
        if FileManager.default.fileExists(atPath: shared.current.path) {
            for file in try FileManager.default.contentsOfDirectory(at: shared.current, includingPropertiesForKeys: nil, options: []) {
                try FileManager.default.moveItem(at: file, to: destination.appendingPathComponent(local(for: file)))
            }
        }
        shared.current = destination
        shared.icloud = enabled
    }

    public static func local(for url: URL) -> String {
        String(url.resolvingSymlinksInPath().path.dropFirst(current.path.count))
    }

    public static func url(for name: String?) -> URL {
        guard let name = name else {
            return current.appendingPathComponent(Int(Date().timeIntervalSince1970).description).appendingPathExtension("md")
        }
        return current.appendingPathComponent(name)
    }

    static var icloudURL: URL {
        FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.club.idk.Markology")!.appendingPathComponent("Documents").resolvingSymlinksInPath()
    }

    static var localURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.club.idk.Markology")!.appendingPathComponent("Documents").resolvingSymlinksInPath()
    }

    private let disableCloud = "disableCloud"
    private let defaults = UserDefaults(suiteName: "group.club.idk.Markology")!
    var current: URL
    var icloud: Bool {
        didSet {
            defaults.set(!icloud, forKey: disableCloud)
        }
    }

    init() {
        #if DEBUG
            if let dir = ProcessInfo.processInfo.environment["MARKOLOGY_DIR"] {
                icloud = false
                current = URL(fileURLWithPath: dir)
                return
            }
        #endif
        guard !defaults.bool(forKey: disableCloud), Container.icloudEnabled else {
            defaults.set(true, forKey: disableCloud)
            icloud = false
            current = Container.localURL
            return
        }
        icloud = true
        current = Container.icloudURL
    }
}
