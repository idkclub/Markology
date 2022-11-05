import Notes
import UIKit
import UIKitPlus

extension Entry.Link {
    class Cell: UITableViewCell, RenderCell {
        func render(_ value: (link: Entry.Link, note: String)) {
            var content = UIListContentConfiguration.valueCell()
            content.text = value.link.note.name
            if value.link.note.name != value.link.text,
               value.note != value.link.text
            {
                content.secondaryText = value.link.text
            }
            contentConfiguration = content
        }
    }
}

extension ID {
    class Cell: UITableViewCell, RenderCell {
        func render(_ id: ID) {
            var content = defaultContentConfiguration()
            if id.name == "" {
                content.text = "Empty Note"
                content.textProperties.color = .placeholderText
            } else {
                content.text = id.name
            }
            contentConfiguration = content
        }
    }
}
