import Markdown
import UIKit

class NoteView: UITextView {
    var tableView: UITableView?
    var note: Note? {
        didSet {
            render(editable: false)
        }
    }

    init(frame: CGRect = .infinite) {
        let layoutManager = LayoutManager()
        let textStorage = NSTextStorage()
        let textContainer = NSTextContainer()
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        super.init(frame: frame, textContainer: textContainer)
        delegate = self
        isEditable = true
        linkTextAttributes = [:]
        smartDashesType = .no
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(editable: Bool) {
        defer {
            tableView?.beginUpdates()
            tableView?.endUpdates()
        }
        guard let note = note else {
            attributedText = "".body
            return
        }
        let doc = Document(parsing: note.text)
        let text: NSMutableAttributedString
        if editable {
            var visitor = EditVisitor(text: note.text)
            text = visitor.visit(doc)
        } else {
            var visitor = NoteVisitor()
            text = visitor.visit(doc)
        }
        attributedText = text.setMissing(key: .foregroundColor, value: UIColor.label)
    }
}

extension NoteView: UITextViewDelegate {
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        render(editable: true)
        return true
    }
    
    func textViewDidEndEditing(_ textView: UITextView) {
        render(editable: false)
    }
    
    func textViewDidChange(_ textView: UITextView) {
        let select = selectedRange
        let string = attributedText.string
        let doc = Document(parsing: string)
        var visitor = EditVisitor(text: string)
        attributedText = visitor.visit(doc)
            .setMissing(key: .foregroundColor, value: UIColor.label)
        selectedRange = select
        tableView?.beginUpdates()
        tableView?.endUpdates()
    }
}

extension NoteView {
    struct EditVisitor: MarkupVisitor {
        let lengths: [Int: (String, Int)]
        var text: NSMutableAttributedString

        init(text: String) {
            self.text = text.body
            var offset = 0
            lengths = text.components(separatedBy: .newlines).enumerated().reduce(into: [:]) {
                $0[$1.offset] = ($1.element, offset)
                offset += $1.element.utf16.count + 1
            }
        }
        
        func index(for source: SourceRange.Bound) -> Int? {
            guard let (line, offset) = lengths[source.line - 1],
                  let column = String(line.utf8.prefix(source.column - 1))?.utf16.count else { return nil }
            return offset + column
        }
        
        func range(for source: Markup) -> NSRange? {
            guard let range = source.range,
                  let low = index(for: range.lowerBound),
                  let high = index(for: range.upperBound) else { return nil }
            return NSRange(location: low, length: high - low)
        }
        
        mutating func defaultVisit(_ markup: Markdown.Markup) -> NSMutableAttributedString {
            markup.children.reduce(text) {
                visit($1)
            }
        }
        
        mutating func visitEmphasis(_ emphasis: Emphasis) -> NSMutableAttributedString {
            guard let range = range(for: emphasis) else { return text }
            return defaultVisit(emphasis)
                .apply(trait: .traitItalic, range: range)
        }

        mutating func visitHeading(_ heading: Heading) -> NSMutableAttributedString {
            guard let range = range(for: heading) else { return text }
            return defaultVisit(heading)
                .apply(size: heading.size, range: range)
        }

        mutating func visitLink(_ link: Link) -> NSMutableAttributedString {
            guard let range = range(for: link),
                  let url = link.destination else { return text }
            return defaultVisit(link)
                .adding(key: .link, value: url, range: range)
                .adding(key: .foregroundColor, value: link.color, range: range)
        }
        
        var quoting = false
        
        mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSMutableAttributedString {
            guard let range = range(for: blockQuote) else { return text }
            quoting = true
            defer { quoting = false }
            return defaultVisit(blockQuote)
                .setMissing(key: .verticalRule, value: [Indent.quote], range: range)
                .setMissing(key: .foregroundColor, value: UIColor.secondaryLabel, range: range)
                .indent(for: .quote, range: range)
        }
        
        mutating func visitStrong(_ strong: Strong) -> NSMutableAttributedString {
            guard let range = range(for: strong) else { return text }
            return defaultVisit(strong)
                .apply(trait: .traitBold, range: range)
        }
        
        mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> NSMutableAttributedString {
            guard let range = range(for: strikethrough) else { return text }
            return defaultVisit(strikethrough)
                .adding(key: .strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        
        mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSMutableAttributedString {
            guard let range = range(for: thematicBreak) else { return text }
            return text.adding(key: .horizontalRule, value: true, range: range)
        }
        
        func visitCodeBlock(_ codeBlock: CodeBlock) -> NSMutableAttributedString {
            guard let range = range(for: codeBlock) else { return text }
            return text.adding(.code, range: range)
        }
        
        func visitHTMLBlock(_ html: HTMLBlock) -> NSMutableAttributedString {
            guard let range = range(for: html) else { return text }
            return text.adding(.html, range: range)
        }
        
        func visitInlineCode(_ inlineCode: InlineCode) -> NSMutableAttributedString {
            guard let range = range(for: inlineCode) else { return text }
            return text.adding(.code, range: range)
        }
        
        func visitInlineHTML(_ inlineHTML: InlineHTML) -> NSMutableAttributedString {
            guard let range = range(for: inlineHTML) else { return text }
            return text.adding(.html, range: range)
        }
    }
}

extension NoteView {
    struct NoteVisitor: MarkupVisitor {
        var indent = [Indent]()

        mutating func block(_ markup: Markdown.Markup) -> NSMutableAttributedString {
            let result = defaultVisit(markup)
            guard markup.indexInParent + 1 != markup.parent?.childCount else { return result }
            return result
                .newline
                .newline
        }

        mutating func defaultVisit(_ markup: Markdown.Markup) -> NSMutableAttributedString {
            markup.children.reduce(into: NSMutableAttributedString()) {
                $0.append(visit($1))
            }
        }

        mutating func visitEmphasis(_ emphasis: Emphasis) -> NSMutableAttributedString {
            defaultVisit(emphasis)
                .apply(trait: .traitItalic)
        }

        mutating func visitHeading(_ heading: Heading) -> NSMutableAttributedString {
            block(heading)
                .apply(size: heading.size)
        }

        mutating func visitLink(_ link: Markdown.Link) -> NSMutableAttributedString {
            guard let url = link.destination else { return defaultVisit(link) }
            return defaultVisit(link)
                .adding(key: .link, value: url)
                .adding(key: .foregroundColor, value: link.color)
        }

        mutating func visitOrderedList(_ orderedList: OrderedList) -> NSMutableAttributedString {
            indent.append(.list)
            defer { indent.remove(at: indent.lastIndex(of: .list)!) }
            return block(orderedList)
                .indent(for: .list)
        }

        mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> NSMutableAttributedString {
            indent.append(.list)
            defer { indent.remove(at: indent.lastIndex(of: .list)!) }
            return block(unorderedList)
                .indent(for: .list)
        }

        mutating func visitListItem(_ listItem: ListItem) -> NSMutableAttributedString {
            let body = block(listItem)
            switch listItem.parent {
            case is UnorderedList:
                return "• "
                    .body
                    .appending(body)
            case is OrderedList:
                return "\(listItem.indexInParent + 1). "
                    .body
                    .apply(trait: .traitMonoSpace)
                    .appending(body)
            default:
                // TODO: Checkboxes?
                return body
            }
        }

        mutating func visitParagraph(_ paragraph: Paragraph) -> NSMutableAttributedString {
            block(paragraph)
        }

        mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSMutableAttributedString {
            indent.append(.quote)
            defer { indent.remove(at: indent.lastIndex(of: .quote)!) }
            return block(blockQuote)
                .setMissing(key: .verticalRule, value: indent)
                .setMissing(key: .foregroundColor, value: UIColor.secondaryLabel)
                .indent(for: .quote)
        }

        mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> NSMutableAttributedString {
            defaultVisit(strikethrough)
                .adding(key: .strikethroughStyle, value: NSUnderlineStyle.single.rawValue)
        }
        
        mutating func visitStrong(_ strong: Strong) -> NSMutableAttributedString {
            defaultVisit(strong)
                .apply(trait: .traitBold)
        }

        func visitTable(_ table: Table) -> NSMutableAttributedString {
            // TODO: Figure out how to render a custom view.
            table.format()
                .html
                .newline
                .newline
        }

        func visitLineBreak(_ lineBreak: LineBreak) -> NSMutableAttributedString {
            "\n".body
        }

        func visitSoftBreak(_ softBreak: SoftBreak) -> NSMutableAttributedString {
            " ".body
        }

        func visitThematicBreak(_ thematicBreak: ThematicBreak) -> NSMutableAttributedString {
            NSMutableAttributedString(string: "\n", attributes: [
                .horizontalRule: true,
            ])
        }

        func visitInlineHTML(_ inlineHTML: InlineHTML) -> NSMutableAttributedString {
            inlineHTML.rawHTML
                .html
        }

        func visitHTMLBlock(_ html: HTMLBlock) -> NSMutableAttributedString {
            html.rawHTML
                .html
                .newline
        }

        func visitCodeBlock(_ codeBlock: CodeBlock) -> NSMutableAttributedString {
            let code = codeBlock.code
                .code
                .newline
            if let lang = codeBlock.language {
                return lang.label
                    .newline
                    .appending(code)
            }
            return code
        }

        func visitInlineCode(_ inlineCode: InlineCode) -> NSMutableAttributedString {
            inlineCode.code
                .code
        }

        func visitText(_ text: Markdown.Text) -> NSMutableAttributedString {
            text.plainText.body
        }
    }
}

extension NoteView {
    class LayoutManager: NSLayoutManager {
        override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            guard let context = UIGraphicsGetCurrentContext() else { return }
            UIGraphicsPushContext(context)
            context.setFillColor(UIColor.label.cgColor)
            textStorage?.enumerateAttribute(.horizontalRule, in: glyphsToShow) { value, range, _ in
                guard value != nil else { return }
                let glyph = glyphIndexForCharacter(at: range.lowerBound)
                let rect = lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                let usedRect = lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
                let padding = textContainer(forGlyphAt: glyph, effectiveRange: nil)?.lineFragmentPadding ?? 0
                let x = usedRect.minX + padding + origin.x
                context.fill(CGRect(x: x, y: rect.minY + origin.y, width: rect.maxX - x + origin.x - padding, height: 1))
            }
            context.setFillColor(UIColor.secondaryLabel.cgColor)
            textStorage?.enumerateAttribute(.verticalRule, in: glyphsToShow) { value, range, _ in
                guard let value = value as? [Indent] else { return }
                var x = 0.0
                var y = 0.0
                var maxY = 0.0
                var initial = true
                enumerateLineFragments(forGlyphRange: glyphRange(forCharacterRange: range, actualCharacterRange: nil)) { rect, usedRect, container, _, _ in
                    if initial {
                        x = rect.minX + container.lineFragmentPadding + origin.x
                        y = rect.minY
                        initial = false
                    }
                    maxY = rect.maxY
                }
                var offset = 0.0
                value.forEach {
                    if $0 == .quote {
                        context.fill(CGRect(x: x + offset, y: y + origin.y, width: 1, height: maxY - y))
                    }
                    offset += $0.offset
                }
            }
            UIGraphicsPopContext()
        }
    }

    enum Indent {
        case list, quote
        var offset: CGFloat {
            switch self {
            case .list:
                return 20
            case .quote:
                return 10
            }
        }
    }
}

private extension Heading {
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

private extension Link {
    var color: UIColor {
        guard let url = destination else { return .label }
        return url.contains(":") || url.contains("//") ? UIColor.idkCyan : UIColor.idkMagenta
    }
}

private extension NSAttributedString.Key {
    static let horizontalRule = NSAttributedString.Key(rawValue: "horizontalRule")
    static let verticalRule = NSAttributedString.Key(rawValue: "verticalRule")
}

private extension NSMutableAttributedString {
    var range: NSRange {
        NSRange(location: 0, length: length)
    }
    
    var newline: Self {
        appending(NSAttributedString(string: "\n"))
    }

    func indent(for type: NoteView.Indent, range: NSRange? = nil) -> Self {
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
    
    func adding(_ attrs: [NSAttributedString.Key : Any], range: NSRange?) -> Self {
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

private extension UIFont {
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

private extension [NSAttributedString.Key : Any] {
    static let code: Self = [
        .backgroundColor: UIColor.secondarySystemFill,
        .foregroundColor: UIColor.secondaryLabel,
        .strokeColor: UIColor.idkCyan,
        .font: UIFont.preferredFont(forTextStyle: .body)
            .apply(trait: .traitMonoSpace),
    ]
    
    static let html: Self =  [
        .foregroundColor: UIColor.secondaryLabel,
        .font: UIFont.preferredFont(forTextStyle: .body)
            .apply(trait: .traitMonoSpace),
    ]
}

private extension String {
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
