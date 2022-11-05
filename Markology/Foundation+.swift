import UIKit

extension UIEdgeInsets {
    static var padded = UIEdgeInsets(top: 15, left: 15, bottom: 15, right: 15)
}

extension URL {
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

protocol Bindable: AnyObject {}

extension Bindable {
    func with<T>(_ key: WritableKeyPath<Self, T>) -> ((T) -> Void) {
        { [weak self] in
            self?[keyPath: key] = $0
        }
    }
}
