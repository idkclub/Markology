import UIKit

extension Note {
    class Image: UITableViewCell {
        static let id = "image"
        let display = UIImageView()
        var height: NSLayoutConstraint?

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            display.anchored(to: contentView, horizontal: true, top: true, bottom: true)
            display.contentMode = .scaleAspectFit
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func render(image: UIImage?) {
            guard let image = image else { return }
            display.image = image
            if let height = height {
                display.removeConstraint(height)
            }
            height = display.heightAnchor.constraint(equalTo: display.widthAnchor, multiplier: image.size.height / image.size.width)
            height?.isActive = true
            height?.priority = .defaultHigh
        }
    }
}
