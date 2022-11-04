import Markdown
import UIKit

public class MarkView: UITextView {
    convenience init() {
        let layoutManager = LayoutManager()
        let textStorage = NSTextStorage()
        let textContainer = NSTextContainer()
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        self.init(frame: .zero, textContainer: textContainer)
        layoutManager.delegate = self
        linkTextAttributes = [:]
        smartDashesType = .no
    }

    override public var keyCommands: [UIKeyCommand] {
        commandable != nil
            ? [UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(command))]
            : []
    }

    public var commandable: KeyCommandable?

    @objc func command(_ command: UIKeyCommand) {
        commandable?.handle(command)
    }

    public var resolver: PathResolver?

    public static let checkboxScheme = "checkbox"
    public var linkCheckboxes: Bool = false

    var attachments: Set<UIView> = []

    public func render(text: String, includingMarkup: Bool) {
        if includingMarkup {
            attributedText = EditVisitor.process(text: text)
            return
        }
        var visitor = NoteVisitor(checkbox: linkCheckboxes, resolver: resolver)
        attributedText = visitor.process(markup: Document(parsing: text))
    }
}

public protocol KeyCommandable {
    func handle(_: UIKeyCommand)
}

public protocol PathResolver {
    func resolve(path: String) -> String?
}

extension MarkView: NSLayoutManagerDelegate {
    public func layoutManager(_ layoutManager: NSLayoutManager, didCompleteLayoutFor textContainer: NSTextContainer?, atEnd layoutFinishedFlag: Bool) {
        guard layoutFinishedFlag else { return }
        var seen: Set<UIView> = []
        attributedText.enumerateAttribute(.attachment, in: attributedText.range) { value, range, _ in
            guard let value = value as? Table else { return }
            if value.view.superview != self {
                value.view.removeFromSuperview()
                addSubview(value.view)
            }
            seen.insert(value.view)
            let glyph = layoutManager.glyphIndexForCharacter(at: range.lowerBound)
            let usedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
            value.view.frame = usedRect.offsetBy(dx: textContainerInset.left, dy: textContainerInset.top)
        }
        attachments.forEach {
            if !seen.contains($0) {
                $0.removeFromSuperview()
            }
        }
        attachments = seen
    }
}

extension MarkView {
    class Table: NSTextAttachment {
        lazy var cells: [[UITextView]] = {
            guard let table = table else { return [] }
            var rows = [table.head.cells]
            rows.append(contentsOf: table.body.rows.map { $0.cells })
            return rows.map {
                $0.enumerated().map { x, cell in
                    let text = UITextView()
                    let paragraph = NSMutableParagraphStyle()
                    switch table.columnAlignments[x] {
                    case .left:
                        paragraph.alignment = .left
                    case .right:
                        paragraph.alignment = .right
                    case .center:
                        paragraph.alignment = .center
                    default:
                        break
                    }
                    var visitor = NoteVisitor()
                    text.attributedText = visitor.process(markup: cell)
                        .adding(key: .paragraphStyle, value: paragraph)
                    text.backgroundColor = .clear
                    text.isScrollEnabled = false
                    text.isEditable = false
                    view.addSubview(text)
                    return text
                }
            }
        }()

        var view = UIScrollView()
        var table: Markdown.Table?
        convenience init(for table: Markdown.Table) {
            self.init(data: nil, ofType: "net.daringfireball.markdown")
            self.table = table
        }

        var lastWidth = 0.0
        var size = CGSize.zero
        func layout(width: CGFloat) {
            let clamped = min(width, 400)
            guard clamped != lastWidth, let table = table else { return }
            lastWidth = clamped
            var widths: [CGFloat] = Array(repeating: 0.0, count: table.maxColumnCount)
            var heights: [CGFloat] = Array(repeating: 0.0, count: cells.count)
            cells.enumerated().forEach { y, row in
                row.enumerated().forEach { x, cell in
                    let size = cell.sizeThatFits(CGSize(width: clamped, height: .infinity))
                    widths[x] = max(widths[x], size.width)
                    heights[y] = max(heights[y], size.height)
                }
            }
            var widthOffset = 0.0
            var heightOffset = 0.0
            cells.enumerated().forEach { y, row in
                let height = heights[y]
                widthOffset = 0
                row.enumerated().forEach { x, cell in
                    let width = widths[x]
                    let rect = CGRect(x: widthOffset, y: heightOffset, width: width, height: height)
                    if cell.frame != rect {
                        cell.frame = rect
                    }
                    widthOffset += width
                }
                heightOffset += height
            }
            size = CGSize(width: widthOffset, height: heightOffset)
            view.contentSize = size
        }

        static let padding = 20.0
        override func attachmentBounds(for textContainer: NSTextContainer?, proposedLineFragment lineFrag: CGRect, glyphPosition position: CGPoint, characterIndex charIndex: Int) -> CGRect {
            layout(width: lineFrag.width - Table.padding)
            return CGRect(origin: .zero, size: size)
        }

        override func image(forBounds imageBounds: CGRect, textContainer: NSTextContainer?, characterIndex charIndex: Int) -> UIImage? {
            nil
        }
    }
}

extension MarkView {
    class LayoutManager: NSLayoutManager {
        override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: CGPoint) {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            guard let context = UIGraphicsGetCurrentContext(),
                  let textStorage = textStorage else { return }
            let range = characterRange(forGlyphRange: glyphsToShow, actualGlyphRange: nil)
            UIGraphicsPushContext(context)
            context.setFillColor(UIColor.label.cgColor)
            textStorage.enumerateAttribute(.horizontalRule, in: range) { value, range, _ in
                guard value != nil else { return }
                let glyph = glyphIndexForCharacter(at: range.lowerBound)
                let rect = lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                let usedRect = lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
                let padding = textContainer(forGlyphAt: glyph, effectiveRange: nil)?.lineFragmentPadding ?? 0
                let x = usedRect.minX + padding + origin.x
                context.fill(CGRect(x: x, y: rect.minY + origin.y, width: rect.maxX - x + origin.x - padding, height: 1))
            }
            context.setFillColor(UIColor.secondaryLabel.cgColor)
            textStorage.enumerateAttribute(.verticalRule, in: range) { value, range, _ in
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
