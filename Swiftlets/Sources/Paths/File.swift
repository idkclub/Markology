import Foundation

public struct File {
    public typealias Name = String
    public let url: URL
    public let name: Name

    init(in container: URL, named: Name) {
        url = container.appendingPathComponent(named).standardizedFileURL
        name = named
    }

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

public extension File.Name {
    func use(for destination: File.Name) -> Self? {
        guard let path = destination.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return use(forEncoded: path)
    }

    func use(forEncoded path: String) -> Self? {
        guard let from = addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: path, relativeTo: URL(string: from))?.path
    }
}
