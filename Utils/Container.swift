import Foundation

public class Container {
    static let shared = Container()
    public static var icloudEnabled: Bool { FileManager.default.ubiquityIdentityToken != nil }
    public static var current: URL { shared.current }
    public static var icloud: Bool { shared.icloud }

    // TODO: Move files from source to destination on toggle.
    public static func setCloud(enabled: Bool) {
        shared.icloud = enabled
        shared.current = enabled ? icloudURL : localURL
    }

    public static func local(for url: URL) -> String {
        String(url.path.dropFirst(current.path.count))
    }

    public static func url(for name: String?) -> URL {
        guard let name = name else {
            return current.appendingPathComponent(Int(Date().timeIntervalSince1970).description).appendingPathExtension("md")
        }
        return current.appendingPathComponent(name)
    }

    static var icloudURL: URL {
        FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.club.idk.Markology")!.appendingPathComponent("Documents")
    }

    static var localURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.club.idk.Markology")!.appendingPathComponent("Documents")
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
