import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    class RootController: UISplitViewController {
        let page = UINavigationController()
        override func viewDidLoad() {
            super.viewDidLoad()
            page.navigationBar.prefersLargeTitles = true
            page.viewControllers = [UIViewController()]
            setViewController(MenuController(delegate: self), for: .primary)
            setViewController(page, for: .secondary)
            delegate = self
        }
    }

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootController(style: .doubleColumn)
        window.makeKeyAndVisible()
        self.window = window
    }
}

extension SceneDelegate.RootController: UISplitViewControllerDelegate {
    func splitViewController(_: UISplitViewController, topColumnForCollapsingToProposedTopColumn _: UISplitViewController.Column) -> UISplitViewController.Column {
        .primary
    }
}

extension SceneDelegate.RootController: MenuDelegate {
    private func navigate(to controller: UIViewController) {
        page.viewControllers[0] = controller
        page.popToRootViewController(animated: true)
        show(.secondary)
    }

    func select(note: Reference) {
        navigate(to: ViewController(note: note))
    }

    func create(query: String) {
        present(EditController(text: EditController.body(from: query)) { [weak self] in
            self?.navigate(to: ViewController(note: Reference(file: World.shared.local(for: $0), name: "")))
        }, animated: true)
    }

    func search(query: String) {
        navigate(to: ResultController(query: query))
    }
}
