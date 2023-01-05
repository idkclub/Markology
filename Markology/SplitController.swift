import Combine
import Notes
import UIKit

class SplitController: UISplitViewController {
    let history = UINavigationController()
    var restore: ID?
    var errors: AnyCancellable?
    override func viewDidLoad() {
        super.viewDidLoad()
        history.navigationBar.prefersLargeTitles = true
        setViewController(MenuController(), for: .primary)
        setViewController(history, for: .secondary)
        let controller: UIViewController
        if let restore = restore {
            controller = NoteController.with(id: restore)
        } else {
            controller = EmptyController()
        }
        history.viewControllers = [controller]
        primaryBackgroundStyle = .sidebar
        delegate = self
        errors = Engine.errors.sink(receiveValue: alert)
    }
}

extension SplitController: UISplitViewControllerDelegate {
    func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        .primary
    }
}
