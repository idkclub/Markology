import UIKit
import Utils

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options _: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootController(style: .doubleColumn)
        window.makeKeyAndVisible()
        self.window = window
    }
}

private class RootController: UISplitViewController {
    let page = UINavigationController()
    override func viewDidLoad() {
        super.viewDidLoad()
        page.navigationBar.prefersLargeTitles = true
        page.viewControllers = [NoteDetailController(note: Reference(file: "/index.md", name: ""))]
        setViewController(MenuController(delegate: self), for: .primary)
        setViewController(page, for: .secondary)
        preferredDisplayMode = .oneBesideSecondary
        delegate = self
    }
}

extension RootController: UISplitViewControllerDelegate {
    func splitViewController(_: UISplitViewController, topColumnForCollapsingToProposedTopColumn _: UISplitViewController.Column) -> UISplitViewController.Column {
        .primary
    }
}

extension RootController: MenuDelegate {
    private func navigate(to controller: UIViewController) {
        page.viewControllers[0] = controller
        page.popToRootViewController(animated: true)
        show(.secondary)
    }

    func select(note: Reference) {
        navigate(to: NoteDetailController(note: note))
    }

    func create(query: String) {
        present(EditController(text: EditController.body(from: query)) { [weak self] in
            self?.navigate(to: NoteDetailController(note: Reference(file: Container.local(for: $0), name: "")))
        }, animated: true)
    }

    func search(query: String) {
        navigate(to: SearchResultController(query: query))
    }
}
