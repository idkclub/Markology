import UIKit

extension UINavigationController {
    func pop() {
        guard viewControllers.count < 2 else {
            popViewController(animated: true)
            return
        }
        splitViewController?.show(.primary)
    }

    private func splitViewController() -> UISplitViewController? {
        guard let split = parent as? UISplitViewController else {
            return parent?.splitViewController
        }
        return split
    }
}
