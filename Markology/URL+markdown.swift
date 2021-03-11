import Foundation

extension URL {
    var isMarkdown: Bool {
        pathExtension == "md"
    }
}
