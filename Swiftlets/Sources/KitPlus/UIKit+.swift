import UIKit

public extension UIView {
    func pinned(to view: UIView, withInset: CGFloat = 0, bottom: Bool = true, top: Bool = true) -> Self {
        view.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        var constraints = [
            leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: withInset),
            trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -withInset),
        ]
        if top {
            constraints.append(topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: withInset))
        }
        if bottom {
            constraints.append(
                bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -withInset))
        }
        NSLayoutConstraint.activate(constraints)
        return self
    }

    @available(iOS 15.0, *)
    func pinned(toKeyboardAnd view: UIView, withInset: CGFloat = 0, top: Bool = true) -> Self {
        let view = pinned(to: view, withInset: withInset, bottom: false, top: top)
        bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor).isActive = true
        return view
    }
}

public extension UITextView {
    func range(for range: NSRange) -> UITextRange? {
        guard let start = position(from: beginningOfDocument, offset: range.location),
              let end = position(from: start, offset: range.length),
              let range = textRange(from: start, to: end) else { return nil }
        return range
    }
}

public extension UITableView {
    func register<T: RenderCell>(_ cell: T.Type) {
        register(T.self, forCellReuseIdentifier: T.reuse)
    }

    func render<T: RenderCell>(_ value: T.Value, for indexPath: IndexPath) -> T {
        let cell = dequeueReusableCell(withIdentifier: T.reuse, for: indexPath) as! T
        cell.render(value)
        return cell
    }
}

public extension UICollectionView {
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

public protocol RenderCell<Value>: NSObject {
    associatedtype Value
    func render(_: Value)
}

private extension RenderCell {
    static var reuse: String {
        NSStringFromClass(self)
    }
}
