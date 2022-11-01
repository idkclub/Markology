import Markdown
import UIKit

extension Heading {
    var size: CGFloat {
        switch level {
        case 1:
            return UIFont.preferredFont(forTextStyle: .title1).pointSize
        case 2:
            return UIFont.preferredFont(forTextStyle: .title2).pointSize
        default:
            return UIFont.preferredFont(forTextStyle: .title3).pointSize
        }
    }
}

extension Link {
    static let urlCharacters = CharacterSet(charactersIn: ":?@#").union(.urlPathAllowed)

    var color: UIColor {
        guard destination != nil else { return .label }
        return absolute ? UIColor.idkCyan : UIColor.idkMagenta
    }

    var absolute: Bool {
        guard let destination = destination else { return false }
        return destination.contains("//") || destination.contains(":")
    }

    var encoded: String? {
        destination?.addingPercentEncoding(withAllowedCharacters: Link.urlCharacters)
    }
}

extension Image {
    var color: UIColor {
        guard source != nil else { return .label }
        return absolute ? UIColor.idkCyan : UIColor.idkMagenta
    }

    var absolute: Bool {
        guard let source = source else { return false }
        return source.contains("//") || source.contains(":")
    }

    var encoded: String? {
        source?.addingPercentEncoding(withAllowedCharacters: Link.urlCharacters)
    }
}
