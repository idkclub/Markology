import Combine
import UIKit

public class KeyboardGuide: UILayoutGuide {
    public let offset = CurrentValueSubject<CGFloat, Never>(0)
    lazy var height = heightAnchor.constraint(equalToConstant: 0)
    var hideObserver: NSObjectProtocol?
    var showObserver: NSObjectProtocol?
    var view: UIView?
    public static func within(view: UIView) -> KeyboardGuide {
        let guide = KeyboardGuide()
        view.addLayoutGuide(guide)
        guide.install(in: view)
        return guide
    }

    func install(in view: UIView) {
        self.view = view
        NSLayoutConstraint.activate([
            height,
            bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        hideObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: nil, using: { [weak self] notification in
            self?.change(to: 0, notification: notification)
        })
        showObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil, using: { [weak self] notification in
            guard let keyboard = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let window = view.window else { return }
            let frame = window.convert(keyboard, from: UIScreen.main.coordinateSpace)
            self?.change(to: max(window.bounds.maxY - frame.minY - view.safeAreaInsets.bottom, 0), notification: notification)
        })
    }

    func change(to: CGFloat, notification: Notification? = nil) {
        let duration = notification?.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
        offset.send(to)
        UIView.animate(withDuration: duration, animations: {
            self.height.constant = to
            self.view?.layoutIfNeeded()
        })
    }
}
