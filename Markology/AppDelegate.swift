import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        builder.remove(menu: .format)
        builder.remove(menu: .services)
        builder.remove(menu: .toolbar)
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let scene = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        scene.delegateClass = SceneDelegate.self
        return scene
    }
}

class SceneDelegate: NSObject, UISceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = SplitController(style: .doubleColumn)
        window.makeKeyAndVisible()
        self.window = window
    }
}

class SplitController: UISplitViewController {
    let history = UINavigationController()
    override func viewDidLoad() {
        super.viewDidLoad()
        history.navigationBar.prefersLargeTitles = true
        setViewController(MenuController(), for: .primary)
        setViewController(history, for: .secondary)
        history.viewControllers = [NoteController()]
        delegate = self
    }
}

extension SplitController: UISplitViewControllerDelegate {
    func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column {
        .primary
    }
}
