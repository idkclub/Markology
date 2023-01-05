import Combine
import UIKit

public class KeyboardGuide: UILayoutGuide {
    public let offset = CurrentValueSubject<CGFloat, Never>(0)
    lazy var height = heightAnchor.constraint(equalToConstant: 0)
    var hideObserver: NSObjectProtocol?
    var showObserver: NSObjectProtocol?
    var view: UIView?
    public static func within(view: UIView) -> KeyboardGuide {
        KeyboardGuide().install(in: view)
    }

    func install(in view: UIView) -> Self {
        self.view = view
        view.addLayoutGuide(self)
        NSLayoutConstraint.activate([
            height,
            bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        hideObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: nil, using: change)
        showObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil, using: change)
        return self
    }

    func change(for notification: Notification) {
        var delta = 0.0
        if let view = view,
           let window = view.window,
           let keyboard = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)
        {
            let screen = notification.object as? UIScreen
            let frame = window.convert(keyboard, from: UIScreen.main.coordinateSpace)
            if screen == nil || frame.width == screen?.bounds.width {
                delta = max(window.bounds.maxY - frame.minY - view.safeAreaInsets.bottom, 0)
            }
        }
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
        offset.send(delta)
        UIView.animate(withDuration: duration, animations: {
            self.height.constant = delta
            self.view?.layoutIfNeeded()
        })
    }
}
