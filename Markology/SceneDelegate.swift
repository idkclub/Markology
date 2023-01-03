import Notes
import Paths
import UIKit

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
