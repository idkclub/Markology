import UIKit

public class TappableHeader: UITableViewHeaderFooterView, RenderCell {
    lazy var tapGesture = {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(self.onTap))
        self.addGestureRecognizer(gesture)
        return gesture
    }()

    var action: (() -> Void)?

    public func render(_ action: @escaping () -> Void) {
        _ = tapGesture
        self.action = action
    }

    @objc private func onTap() {
        action?()
    }
}
