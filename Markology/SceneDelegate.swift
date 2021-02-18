import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    class RootController: UISplitViewController {
        let note = ViewController()
        override func viewDidLoad() {
            super.viewDidLoad()
            setViewController(note, for: .secondary)
            setViewController(MenuController(
                select: { [weak self] note in
                    guard let self = self else { return }
                    self.note.set(note: note)
                    self.note.navigationController?.popToRootViewController(animated: true)
                    self.show(.secondary)
                },
                create: { [weak self] query in
                    self?.present(EditController(text: EditController.body(from: query)), animated: true)
                }
            ), for: .primary)
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
