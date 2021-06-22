import UIKit

public class KeyboardGuide: UILayoutGuide {
    var hideObserver: NSObjectProtocol?
    var showObserver: NSObjectProtocol?
    let view: UIView

    public init(view: UIView) {
        self.view = view
        super.init()
        view.addLayoutGuide(self)
        let height = heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            height,
            bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
        hideObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: nil, using: { [weak self] notification in
            height.constant = 0
            self?.animate(notification: notification)
        })
        showObserver = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil, using: { [weak self] notification in
            guard let keyboard = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
                  let window = view.window else { return }
            let frame = window.convert(keyboard, from: UIScreen.main.coordinateSpace)
            height.constant = max(window.bounds.maxY - frame.minY - view.safeAreaInsets.bottom, 0)
            self?.animate(notification: notification)
        })
    }

    func animate(notification: Notification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0
        UIView.animate(withDuration: duration, animations: {
            self.view.layoutIfNeeded()
        })
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let hideObserver = hideObserver {
            NotificationCenter.default.removeObserver(hideObserver)
        }
        if let showObserver = showObserver {
            NotificationCenter.default.removeObserver(showObserver)
        }
    }
}
