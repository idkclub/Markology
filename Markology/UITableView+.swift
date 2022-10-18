import UIKit

extension UITableView {
    func register<T: TableCell>(_ cell: T.Type) {
        register(T.self, forCellReuseIdentifier: T.reuse)
    }

    func render<T: TableCell>(_ value: T.Value, for indexPath: IndexPath) -> T {
        let cell = dequeueReusableCell(withIdentifier: T.reuse, for: indexPath) as! T
        cell.render(value)
        return cell
    }

    func render<T: ConfigCell>(_ value: T.Value, with config: T.Config, for indexPath: IndexPath) -> T {
        let cell = dequeueReusableCell(withIdentifier: T.reuse, for: indexPath) as! T
        cell.config(config)
        cell.render(value)
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

protocol ConfigCell<Config>: TableCell {
    associatedtype Config
    func config(_: Config)
}

protocol TableCell<Value>: UITableViewCell {
    associatedtype Value
    func render(_: Value)
}

private extension TableCell {
    static var reuse: String {
        NSStringFromClass(self)
    }
}
