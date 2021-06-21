import UIKit

public class KeyboardGuide: UILayoutGuide {
    var hideObserver: NSObjectProtocol?
    var showObserver: NSObjectProtocol?
    let view: UIView
    let useSafeArea: Bool

    public init(view: UIView, useSafeArea: Bool = true) {
        self.view = view
        self.useSafeArea = useSafeArea
        super.init()
        view.addLayoutGuide(self)
        let height = heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            height,
            bottomAnchor.constraint(equalTo: useSafeArea ? view.safeAreaLayoutGuide.bottomAnchor : view.bottomAnchor),
        ])
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: nil, using: { [weak self] notification in
            height.constant = 0
            self?.animate(notification: notification)
        })
        NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: nil, using: { [weak self] notification in
            guard let keyboard = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            if useSafeArea {
                let frame = view.convert(keyboard, from: UIScreen.main.coordinateSpace)
                height.constant = max(view.bounds.height - frame.minY - view.safeAreaInsets.bottom, 0)
            } else {
                height.constant = keyboard.height
            }
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
