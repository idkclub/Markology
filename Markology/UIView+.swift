import UIKit

extension UIView {
    func pinned(to view: UIView, withInset: CGFloat = 0, bottom: Bool = true) -> Self {
        view.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        var constraints = [
            leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: withInset),
            trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -withInset),
            topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: withInset),
        ]
        if bottom {
            constraints.append(bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -withInset))
        }
        NSLayoutConstraint.activate(constraints)
        return self
    }
}

extension UITextView {
    func range(for range: NSRange) -> UITextRange? {
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length),
              let range = textRange(from: start, to: end) else { return nil }
        return range
    }
}

extension UITableView {
    func register<T: RenderCell>(_ cell: T.Type) {
        register(T.self, forCellReuseIdentifier: T.reuse)
    }

    func render<T: RenderCell>(_ value: T.Value, for indexPath: IndexPath) -> T {
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

extension UICollectionView {
    func register<T: RenderCell>(_ cell: T.Type) {
        register(T.self, forCellWithReuseIdentifier: T.reuse)
    }

    func render<T: RenderCell>(_ value: T.Value, for indexPath: IndexPath) -> T {
        let cell = dequeueReusableCell(withReuseIdentifier: T.reuse, for: indexPath) as! T
        cell.render(value)
        return cell
    }

    func register<T: RenderCell>(header: T.Type) {
        register(T.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: T.reuse)
    }

    func render<T: RenderCell>(_ value: T.Value, forHeader indexPath: IndexPath) -> T {
        let header = dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: T.reuse, for: indexPath) as! T
        header.render(value)
        return header
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

protocol ConfigCell<Config>: RenderCell {
    associatedtype Config
    func config(_: Config)
}

protocol RenderCell<Value>: NSObject {
    associatedtype Value
    func render(_: Value)
}

private extension RenderCell {
    static var reuse: String {
        NSStringFromClass(self)
    }
}
