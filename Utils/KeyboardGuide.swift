import UIKit

public class KeyboardGuide: UILayoutGuide {
    var observer: NSObjectProtocol?

    public init(view: UIView) {
        super.init()
        view.addLayoutGuide(self)
        let height = heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            height,
            bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        observer = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: nil) { notification in
            guard let window = view.window?.frame,
                  let keyboardBegin = notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect,
                  let keyboard = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            if keyboard == CGRect.zero || (keyboardBegin == CGRect.zero && keyboard.width < window.width) {
                // Floating keyboard present.
                height.constant = 0
                return
            }
            height.constant = max(window.height - keyboard.minY - view.safeAreaInsets.bottom, 0)
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
            UIView.animate(withDuration: duration, animations: {
                view.layoutIfNeeded()
            })
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        guard let observer = observer else { return }
        NotificationCenter.default.removeObserver(observer)
    }
}
