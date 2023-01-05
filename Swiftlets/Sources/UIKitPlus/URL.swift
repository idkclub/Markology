import UIKit

public extension URL {
    func open() {
        #if targetEnvironment(macCatalyst)
            UIApplication.shared.open(self)
        #else
            guard let url = NSURLComponents(url: self, resolvingAgainstBaseURL: true) else { return }
            url.scheme = "shareddocuments"
            guard let url = url.url else { return }
            UIApplication.shared.open(url)
        #endif
    }
}
