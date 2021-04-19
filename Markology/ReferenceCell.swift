import UIKit

class ReferenceCell: UITableViewCell {
    static let id = "reference"

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        accessoryView = UIImageView(image: UIImage(systemName: "chevron.forward"))
        accessoryView?.tintColor = .secondaryLabel
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(name: String) {
        let empty = name == ""
        textLabel?.text = empty ? "Empty Note" : name
        textLabel?.textColor = empty ? .placeholderText : .label
    }
}
