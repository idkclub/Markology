import UIKit

public extension UIView {
    @discardableResult func anchored(to view: UIView, horizontal: Bool = false, top: Bool = false, bottom: Bool = false, constant: CGFloat = 0) -> Self {
        view.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        var constraints: [NSLayoutConstraint] = []
        if horizontal {
            constraints.append(contentsOf: [
                leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: constant),
                trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -constant),
            ])
        }
        if top {
            constraints.append(contentsOf: [
                topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: constant),
            ])
        }
        if bottom {
            constraints.append(contentsOf: [
                bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -constant),
            ])
        }
        NSLayoutConstraint.activate(constraints)
        return self
    }
}
