import Markdown
import UIKit

class TextView: UITextView {
    init(frame: CGRect = .infinite) {
        let layoutManager = LayoutManager()
        let textStorage = NSTextStorage()
        let textContainer = NSTextContainer()
        textStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)
        super.init(frame: frame, textContainer: textContainer)
        linkTextAttributes = [:]
        smartDashesType = .no
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var keyCommands: [UIKeyCommand] {
        [UIKeyCommand(input: "\t", modifierFlags: [], action: #selector(command))]
    }

    var commandable: Commandable?

    @objc func command(_ command: UIKeyCommand) {
        commandable?.handle(command)
    }
}

protocol Commandable {
    func handle(_: UIKeyCommand)
}

extension TextView {
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
