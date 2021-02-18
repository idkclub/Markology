import Foundation

extension URL {
    var markdown: Bool {
        pathExtension == "md"
    }
}
