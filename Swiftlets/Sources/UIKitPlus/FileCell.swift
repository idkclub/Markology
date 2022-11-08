import UIKit

public class FileCell: UITableViewCell, RenderCell {
    var height: NSLayoutConstraint?
    lazy var imageDisplay = {
        let view = UIImageView().pinned(to: contentView)
        view.contentMode = .scaleAspectFit
        return view
    }()

    lazy var textDisplay = {
        let view = UITextView().pinned(to: contentView, layout: true)
        view.isEditable = false
        view.isScrollEnabled = false
        return view
    }()

    override public func prepareForReuse() {
        imageDisplay.image = nil
        imageDisplay.isHidden = true
        textDisplay.text = nil
        textDisplay.isHidden = true
    }

    public func render(_ url: URL) {
        // TODO: Add a spinner.
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, error: &error) { url in
            if let image = UIImage(contentsOfFile: url.path) {
                imageDisplay.image = image
                imageDisplay.isHidden = false
                if let height = height {
                    imageDisplay.removeConstraint(height)
                }
                height = imageDisplay.heightAnchor.constraint(equalTo: imageDisplay.widthAnchor, multiplier: image.size.height / image.size.width)
                height?.isActive = true
                height?.priority = .defaultHigh
            }
            if let text = try? String(contentsOf: url) {
                textDisplay.text = text
                textDisplay.font = .monospacedSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .regular)
                textDisplay.isHidden = false
                return
            }
        }
    }
}
