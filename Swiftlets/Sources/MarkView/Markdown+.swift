import Markdown
import UIKit

public protocol URLish {
    var url: String? { get }
}

extension URLish {
    public var absolute: Bool {
        guard let url = url else { return false }
        return url.contains("//") || url.contains(":")
    }

    var color: UIColor {
        guard url != nil else { return .label }
        return absolute ? Link.absolute : Link.local
    }

    var encoded: String? {
        url?.addingPercentEncoding(withAllowedCharacters: Link.urlCharacters)
    }
}

extension Link: URLish {
    static let urlCharacters = CharacterSet(charactersIn: ":?@#").union(.urlPathAllowed)
    static let absolute = UIColor(red: 0.00, green: 0.58, blue: 0.83, alpha: 1.00)
    static let local = UIColor(red: 0.80, green: 0.00, blue: 0.42, alpha: 1.00)

    public var url: String? {
        destination
    }
}

extension Image: URLish {
    public var url: String? {
        source
    }
}

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
