import UIKit
import Utils

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options _: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        let window = UIWindow(windowScene: windowScene)
        let initial: Reference
        if let resume = session.stateRestorationActivity,
           let file = resume.userInfo?["note"] as? String
        {
            initial = Reference(file: file, name: resume.title ?? "")
        } else {
            initial = Reference(file: "/index.md", name: "")
        }
        window.rootViewController = RootController(initial: initial)
        window.makeKeyAndVisible()
        self.window = window
    }

    func stateRestorationActivity(for _: UIScene) -> NSUserActivity? {
        guard let root = window?.rootViewController as? RootController,
              let note = root.page.viewControllers.last as? NoteDetailController else { return nil }
        let activity = NSUserActivity(activityType: "club.idk.Markology.Note")
        activity.isEligibleForHandoff = true
        activity.title = note.note.name
        activity.userInfo?["note"] = note.note.file
        return activity
    }
}

private class RootController: UISplitViewController {
    let page = UINavigationController()
    let initial: Reference

    init(initial: Reference) {
        self.initial = initial
        super.init(style: .doubleColumn)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        page.navigationBar.prefersLargeTitles = true
        page.viewControllers = [NoteDetailController(note: initial)]
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
