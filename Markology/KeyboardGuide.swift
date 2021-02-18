import UIKit

class KeyboardGuide: UILayoutGuide {
    var observer: NSObjectProtocol?
    lazy var height = heightAnchor.constraint(equalToConstant: 0)

    init(view: UIView) {
        super.init()
        observer = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: nil) { [weak self] notification in
            guard let self = self, let window = view.window?.frame,
                  let keyboard = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
            UIView.animate(withDuration: duration) {
                self.height.constant = max(window.height - keyboard.minY, 0)
                view.layoutIfNeeded()
            }
        }
        view.addLayoutGuide(self)
        NSLayoutConstraint.activate([
            height,
            bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
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
