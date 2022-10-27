import Markdown
import UIKit

struct NoteVisitor: MarkupVisitor {
    static func process(markup: Markup, checkbox: Bool = false) -> NSMutableAttributedString {
        var visitor = NoteVisitor(checkbox: checkbox)
        return visitor.visit(markup)
            .setMissing(key: .foregroundColor, value: UIColor.label)
    }

    var checkbox = false
    var indent = [TextView.Indent]()

    mutating func block(_ markup: Markdown.Markup, rendered: NSMutableAttributedString? = nil) -> NSMutableAttributedString {
        let result = rendered != nil ? rendered! : defaultVisit(markup)
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
        guard let url = link.encoded else { return defaultVisit(link) }
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

    static let checkbox = "checkbox"

    mutating func visitListItem(_ listItem: ListItem) -> NSMutableAttributedString {
        let body = block(listItem)
        let box: String
        // TODO: Clickable checkboxes.
        switch listItem.checkbox {
        case .checked:
            box = "☑ "
        case .unchecked:
            box = "☐ "
        case .none:
            box = ""
        }
        var bullet: NSMutableAttributedString
        switch listItem.parent {
        case is UnorderedList:
            bullet = "• \(box)"
                .body
        case is OrderedList:
            bullet = "\(listItem.indexInParent + 1). "
                .body
                .apply(trait: .traitMonoSpace)
                .appending(box.body)
        default:
            return body
        }
        if checkbox, let lower = listItem.range?.lowerBound {
            bullet = bullet.adding(key: .link, value: "\(NoteVisitor.checkbox)://\(lower.line)")
        }
        return bullet
            .appending(body)
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

    mutating func visitTable(_ table: Table) -> NSMutableAttributedString {
        block(table, rendered: NSMutableAttributedString(attachment: TextView.Table(for: table)))
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
