import Markdown
import UIKit

struct EditVisitor: MarkupVisitor {
    static func process(text: String) -> NSMutableAttributedString {
        let doc = Document(parsing: text)
        var visitor = EditVisitor(text: text)
        return visitor.visit(doc)
            .setMissing(key: .foregroundColor, value: UIColor.label)
    }

    let lengths: [Int: (String, Int)]
    var text: NSMutableAttributedString

    private init(text: String) {
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
              let url = link.encoded else { return text }
        return defaultVisit(link)
            .adding(key: .link, value: url, range: range)
            .adding(key: .foregroundColor, value: link.color, range: range)
    }

    mutating func visitImage(_ image: Image) -> NSMutableAttributedString {
        guard let range = range(for: image),
              let url = image.encoded else { return text }
        return defaultVisit(image)
            .adding(key: .link, value: url, range: range)
            .adding(key: .foregroundColor, value: image.color, range: range)
    }

    var quoteLevel = 0
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> NSMutableAttributedString {
        guard let range = range(for: blockQuote) else { return text }
        quoteLevel += 1
        let quoted = defaultVisit(blockQuote)
            .setMissing(key: .verticalRule, value: [TextView.Indent.quote], range: range)
            .setMissing(key: .foregroundColor, value: UIColor.secondaryLabel, range: range)
        quoteLevel -= 1
        if quoteLevel > 0 {
            return quoted
        }
        return quoted.indent(for: .quote, range: range)
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
