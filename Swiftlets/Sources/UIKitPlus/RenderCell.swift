import Foundation

public protocol RenderCell<Value>: AnyObject {
    associatedtype Value
    func render(_: Value)
}

extension RenderCell {
    static var reuse: String {
        NSStringFromClass(self)
    }
}
