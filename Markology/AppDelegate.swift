import Combine
import Notes
import Paths
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
        let split = SplitController(style: .doubleColumn)
        if let state = session.stateRestorationActivity,
           let file = state.userInfo?["file"] as? File.Name
        {
            split.restore = ID(file: file, name: state.title ?? file)
        }
        window.rootViewController = split
        window.makeKeyAndVisible()
        self.window = window
    }

    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? {
        guard let split = window?.rootViewController as? SplitController,
              let note = split.history.viewControllers.last as? NoteController,
              let id = note.id else { return nil }
        let activity = NSUserActivity(activityType: "\(Engine.bundle).Note")
        activity.isEligibleForHandoff = true
        activity.title = note.title
        activity.userInfo?["file"] = id.file
        return activity
    }
}

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

class EmptyController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Welcome"
        let text = UITextView().pinned(to: view, layout: true)
        text.text = "Select or create a new note on the sidebar to get started."
        text.isSelectable = false
        text.font = UIFont.preferredFont(forTextStyle: .body)
        text.textColor = .secondaryLabel
    }
}
