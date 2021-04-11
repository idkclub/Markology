import UIKit

class TappableHeader: UITableViewHeaderFooterView {
    static let id = "tappable"

    var onTap: (() -> Void)?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapSelector))
        addGestureRecognizer(tapGesture)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func tapSelector() {
        onTap?()
    }
}
