import UIKit

extension UITableView {
    func register<T: Renderable>(_ renderable: T.Type) {
        register(T.Cell.self, forCellReuseIdentifier: T.Cell.reuse)
    }

    func render<T: Renderable>(_ value: T?, for indexPath: IndexPath) -> UITableViewCell {
        let cell = dequeueReusableCell(withIdentifier: T.Cell.reuse, for: indexPath) as! T.Cell
        // TODO: Handle missing.
        if let value = value {
            cell.render(value)
        }
        return cell
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

protocol Renderable {
    associatedtype Cell: TableCell<Self>
}

protocol TableCell<Value>: UITableViewCell {
    associatedtype Value
    static var reuse: String { get }
    func render(_: Value)
}

extension TableCell {
    static var reuse: String {
        NSStringFromClass(self)
    }
}
