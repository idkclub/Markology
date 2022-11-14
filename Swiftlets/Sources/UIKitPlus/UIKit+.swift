import UIKit

public extension UIView {
    enum Anchor {
        case inherit, view, layout, none
        case against(Guide)

        func resolve(from anchor: Anchor, with view: UIView) -> Guide? {
            let target: Anchor
            if case .inherit = self {
                target = anchor
            } else {
                target = self
            }
            switch target {
            case .view:
                return view
            case .layout:
                return view.layoutMarginsGuide
            case let .against(guide):
                return InvertedGuide(guide: guide)
            default:
                return nil
            }
        }
    }

    @discardableResult
    func pinned(to view: UIView, anchor: Anchor = .layout, bottom: Anchor = .inherit, top: Anchor = .inherit, leading: Anchor = .inherit, trailing: Anchor = .inherit, layout: Anchor = .inherit) -> Self {
        view.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        var constraints: [NSLayoutConstraint] = []
        if let guide = bottom.resolve(from: anchor, with: view) {
            constraints.append(bottomAnchor.constraint(equalTo: guide.bottomAnchor))
        }
        if let guide = top.resolve(from: anchor, with: view) {
            constraints.append(topAnchor.constraint(equalTo: guide.topAnchor))
        }
        if let guide = leading.resolve(from: anchor, with: view) {
            constraints.append(leadingAnchor.constraint(equalTo: guide.leadingAnchor))
        }
        if let guide = trailing.resolve(from: anchor, with: view) {
            constraints.append(trailingAnchor.constraint(equalTo: guide.trailingAnchor))
        }
        NSLayoutConstraint.activate(constraints)
        return self
    }
}

public protocol Guide {
    var leadingAnchor: NSLayoutXAxisAnchor { get }
    var trailingAnchor: NSLayoutXAxisAnchor { get }
    var topAnchor: NSLayoutYAxisAnchor { get }
    var bottomAnchor: NSLayoutYAxisAnchor { get }
}

struct InvertedGuide: Guide {
    let guide: Guide

    var leadingAnchor: NSLayoutXAxisAnchor {
        guide.trailingAnchor
    }

    var trailingAnchor: NSLayoutXAxisAnchor {
        guide.leadingAnchor
    }

    var topAnchor: NSLayoutYAxisAnchor {
        guide.bottomAnchor
    }

    var bottomAnchor: NSLayoutYAxisAnchor {
        guide.topAnchor
    }
}

extension UILayoutGuide: Guide {}
extension UIView: Guide {}

public extension UIViewController {
    func add(_ controller: UIViewController) {
        addChild(controller)
        controller.didMove(toParent: self)
    }

    func alert(error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(.init(title: "Okay", style: .cancel) { _ in alert.dismiss(animated: true) })
        DispatchQueue.main.async {
            self.present(alert, animated: true)
        }
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

    func register<T: RenderCell>(header: T.Type) {
        register(T.self, forHeaderFooterViewReuseIdentifier: T.reuse)
    }

    func render<T: RenderCell>(header value: T.Value) -> T {
        let header = dequeueReusableHeaderFooterView(withIdentifier: T.reuse) as! T
        header.render(value)
        return header
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
