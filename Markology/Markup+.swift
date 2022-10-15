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
    var color: UIColor {
        guard let url = destination else { return .label }
        return url.contains(":") || url.contains("//") ? UIColor.idkCyan : UIColor.idkMagenta
    }
}
