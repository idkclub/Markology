import UIKit

extension Note {
    class Image: UITableViewCell {
        static let id = "image"
        let display = UIImageView()

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            display.anchored(to: contentView, horizontal: true, top: true, bottom: true)
            // TODO: Fit image.
            display.contentMode = .scaleAspectFill
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func render(image: UIImage?) {
            display.image = image
        }
    }
}
