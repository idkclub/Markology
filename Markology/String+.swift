import UIKit

extension String {
    var body: NSMutableAttributedString {
        NSMutableAttributedString(string: self, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .body),
        ])
    }

    var code: NSMutableAttributedString {
        NSMutableAttributedString(string: self, attributes: .code)
    }

    var html: NSMutableAttributedString {
        NSMutableAttributedString(string: self, attributes: .html)
    }

    var label: NSMutableAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .right
        return NSMutableAttributedString(string: self, attributes: [
            .backgroundColor: UIColor.secondarySystemBackground,
            .foregroundColor: UIColor.label,
            .font: UIFont.preferredFont(forTextStyle: .body),
            .paragraphStyle: paragraph,
        ])
    }
}

extension NSAttributedString.Key {
    static let horizontalRule = NSAttributedString.Key(rawValue: "horizontalRule")
    static let verticalRule = NSAttributedString.Key(rawValue: "verticalRule")
}

extension [NSAttributedString.Key: Any] {
    static let code: Self = [
        .backgroundColor: UIColor.secondarySystemFill,
        .foregroundColor: UIColor.secondaryLabel,
        .strokeColor: UIColor.idkCyan,
        .font: UIFont.preferredFont(forTextStyle: .body)
            .apply(trait: .traitMonoSpace),
    ]

    static let html: Self = [
        .foregroundColor: UIColor.secondaryLabel,
        .font: UIFont.preferredFont(forTextStyle: .body)
            .apply(trait: .traitMonoSpace),
    ]
}

extension NSMutableAttributedString {
    var range: NSRange {
        NSRange(location: 0, length: length)
    }

    var newline: Self {
        appending(NSAttributedString(string: "\n"))
    }

    func indent(for type: TextView.Indent, range: NSRange? = nil) -> Self {
        // NOTE: This is used to avoid region collapse causing double indents.
        var processed = 0
        enumerateAttribute(.paragraphStyle, in: range ?? self.range) { value, range, _ in
            let previous = (value as? NSParagraphStyle)?.firstLineHeadIndent ?? 0
            let paragraph = NSMutableParagraphStyle()
            paragraph.firstLineHeadIndent = previous + type.offset
            paragraph.headIndent = paragraph.firstLineHeadIndent
            addAttribute(.paragraphStyle, value: paragraph, range: NSRange(max(range.lowerBound, processed) ..< range.upperBound))
            processed = range.upperBound
        }
        return self
    }

    func appending(_ str: NSAttributedString) -> Self {
        append(str)
        return self
    }

    func adding(_ attrs: [NSAttributedString.Key: Any], range: NSRange?) -> Self {
        addAttributes(attrs, range: range ?? self.range)
        return self
    }

    func adding(key: NSAttributedString.Key, value new: Any, range: NSRange? = nil) -> Self {
        addAttribute(key, value: new, range: range ?? self.range)
        return self
    }

    func apply(trait: UIFontDescriptor.SymbolicTraits? = nil, size: CGFloat? = nil, range: NSRange? = nil) -> Self {
        enumerateAttribute(.font, in: range ?? self.range) { value, range, _ in
            guard let value = value as? UIFont else { return }
            addAttribute(.font, value: value.apply(trait: trait, size: size), range: range)
        }
        return self
    }

    func setMissing(key: NSAttributedString.Key, value new: Any, range: NSRange? = nil) -> Self {
        enumerateAttribute(key, in: range ?? self.range) { value, range, _ in
            guard value == nil else { return }
            addAttribute(key, value: new, range: range)
        }
        return self
    }
}

extension UIFont {
    func apply(trait: UIFontDescriptor.SymbolicTraits? = nil, size: CGFloat? = nil) -> UIFont {
        var font = fontDescriptor
        var traits = font.symbolicTraits
        if let trait = trait {
            traits.insert(trait)
            font = fontDescriptor.withSymbolicTraits(traits) ?? font
        }
        return UIFont(descriptor: font, size: size ?? pointSize)
    }
}
