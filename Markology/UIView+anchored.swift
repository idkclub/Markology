import UIKit

extension UIView {
    @discardableResult func anchored(to view: UIView, horizontal: Bool = false, top: Bool = false, bottom: Bool = false) -> Self {
        view.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        var constraints: [NSLayoutConstraint] = []
        if horizontal {
            constraints.append(contentsOf: [
                leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
                trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            ])
        }
        if top {
            constraints.append(contentsOf: [
                topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            ])
        }
        if bottom {
            constraints.append(contentsOf: [
                bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            ])
        }
        NSLayoutConstraint.activate(constraints)
        return self
    }
}
