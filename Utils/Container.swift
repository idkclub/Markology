import Foundation

public class Container {
    public static var current: URL { shared.container }
    public static var icloud: Bool { shared.icloud }
    public static func local(for url: URL) -> String {
        String(url.path.dropFirst(current.path.count))
    }

    public static func url(for name: String?) -> URL {
        guard let name = name else {
            return current.appendingPathComponent(Int(Date().timeIntervalSince1970).description).appendingPathExtension("md")
        }
        return current.appendingPathComponent(name)
    }

    static let shared = Container()
    let container: URL
    let icloud: Bool
    init() {
        // TODO: Handle upgrade / downgrade.
        if let path = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.club.idk.Markology")?.appendingPathComponent("Documents") {
            container = path
            icloud = true
        } else {
            // TODO: Make a shared container (extension has its own home).
            container = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
            icloud = false
        }
    }
}
