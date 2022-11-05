import UIKit

public extension UIView {
    @discardableResult
    func pinned(to view: UIView, withInset: CGFloat = 0, bottom: Bool = true, top: Bool = true, layout: Bool = false) -> Self {
        view.addSubview(self)
        let guide = layout ? view.layoutMarginsGuide : view.safeAreaLayoutGuide
        translatesAutoresizingMaskIntoConstraints = false
        var constraints = [
            leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: withInset),
            trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -withInset),
        ]
        if top {
            constraints.append(topAnchor.constraint(equalTo: guide.topAnchor, constant: withInset))
        }
        if bottom {
            constraints.append(
                bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -withInset))
        }
        NSLayoutConstraint.activate(constraints)
        return self
    }

    @discardableResult
    @available(iOS 15.0, *)
    func pinned(toKeyboardAnd view: UIView, withInset: CGFloat = 0, top: Bool = true) -> Self {
        let view = pinned(to: view, withInset: withInset, bottom: false, top: top)
        bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor).isActive = true
        return view
    }
}

public extension UIViewController {
    func add(_ controller: SubController) {
        addChild(controller)
        controller.arrange(in: view)
        controller.didMove(toParent: self)
    }
}

public protocol SubController: UIViewController {
    func arrange(in parent: UIView)
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
