public protocol Bindable: AnyObject {}

public extension Bindable {
    func with<T>(_ key: WritableKeyPath<Self, T>) -> ((T) -> Void) {
        { [weak self] in
            self?[keyPath: key] = $0
        }
    }
}
