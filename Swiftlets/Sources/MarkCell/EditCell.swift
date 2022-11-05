import Combine
import Markdown
import MarkView
import UIKit
import UIKitPlus

public class EditCell: UITableViewCell {
    var delegate: EditCellDelegate?
    var previous: UITextRange?
    var dirty = false
    var insertSink: AnyCancellable?

    lazy var markdown = {
        let view = MarkView().pinned(to: contentView, layout: true)
        view.isScrollEnabled = false
        view.isEditable = true
        view.delegate = self
        return view
    }()

    func render(_ text: String) {
        markdown.render(text: text, includingMarkup: true)
        markdown.becomeFirstResponder()
    }
}

extension EditCell: RenderCell {
    public typealias Value = (text: String, with: EditCellDelegate)
    public func render(_ value: Value) {
        delegate = value.with
        if let delegate = delegate as? KeyCommandable {
            markdown.commandable = delegate
        }
        if let delegate = delegate as? SearchDelegate {
            insertSink = delegate.addLink.sink { [weak self] in
                guard let markdown = self?.markdown,
                      let selection = markdown.selectedTextRange else { return }
                if selection.start == selection.end,
                   let token = markdown.tokenizer.rangeEnclosingPosition(selection.start, with: .word, inDirection: .storage(.backward))
                {
                    markdown.selectedTextRange = token
                }
                if ["gif", "jpg", "jpeg", "png"].contains(($0.url as NSString).pathExtension.lowercased()) {
                    markdown.insertText("![\($0.text)](\($0.url))")
                } else {
                    markdown.insertText("[\($0.text)](\($0.url))")
                }
            }
        }
        render(value.text)
    }
}

extension EditCell: UITextViewDelegate {
    public func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        guard let range = textView.range(for: characterRange),
              let text = textView.text(in: range) else { return false }
        let doc = Document(parsing: text)
        var visitor = LinkWalker()
        visitor.visit(doc)
        return delegate?.openLink(to: url, with: visitor.text) ?? false
    }

    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let body = textView.text,
              text == "\n",
              let indexRange = Range(range, in: body) else { return true }
        let line = body.lineRange(for: indexRange)
        let prefix = Prefixer.match(body[line])
        guard !prefix.dash else { return true }
        if prefix.prefix != "" {
            dirty = true
            let replace: String
            let selected: Int
            let uiRange: UITextRange?
            if prefix.empty {
                let range = NSRange(line, in: body)
                replace = line.upperBound == body.endIndex ? "\n" : "\n\n"
                selected = range.lowerBound + 1
                uiRange = textView.range(for: range)
            } else {
                replace = "\n\(prefix.prefix)"
                selected = range.upperBound + replace.count
                uiRange = textView.range(for: range)
            }
            guard let uiRange = uiRange else { return true }
            textView.replace(uiRange, withText: replace)
            textView.selectedRange = NSRange(location: selected, length: 0)
            textViewDidChange(textView)
            return false
        }
        return true
    }

    public func textViewDidChange(_ textView: UITextView) {
        dirty = true
        let text = textView.text ?? ""
        delegate?.change(text: text)
        let select = textView.selectedRange
        render(text)
        textView.selectedRange = select
        if let superview = superview as? UITableView {
            superview.beginUpdates()
            superview.endUpdates()
        }
        dirty = false
    }

    public func textViewDidChangeSelection(_ textView: UITextView) {
        guard !dirty,
              let selection = textView.selectedTextRange,
              let superview = superview as? UITableView else { return }
        var position = selection.end
        if position == previous?.end {
            position = selection.start
        }

        var rect = textView.convert(textView.caretRect(for: position), to: superview)
        if rect.origin.y == .infinity {
            rect = convert(bounds, to: superview)
            rect.origin.y = rect.minY + rect.height
            rect.size.height = 50
        } else {
            rect.origin.y -= rect.size.height
            rect.size.height *= 3
        }
        superview.scrollRectToVisible(rect, animated: false)
        previous = textView.selectedTextRange

        guard let delegate = delegate as? SearchDelegate else { return }
        if selection.start != selection.end,
           let text = textView.text(in: selection),
           !text.contains(where: \.isNewline)
        {
            delegate.change(search: text)
        } else if let token = textView.tokenizer.rangeEnclosingPosition(position, with: .word, inDirection: .storage(.backward)),
                  let text = textView.text(in: token)
        {
            delegate.change(search: text)
        }
    }
}

public protocol EditCellDelegate: LinkDelegate {
    func change(text: String)
}

public protocol SearchDelegate {
    var addLink: PassthroughSubject<(url: String, text: String), Never> { get }
    func change(search: String)
}

extension EditCell {
    struct LinkWalker: MarkupWalker {
        var text = ""
        mutating func visitLink(_ link: Markdown.Link) {
            text = link.plainText
        }
    }
}

extension EditCell {
    struct Prefixer {
        var prefix = ""
        var empty = true
        var dash: Bool { dashCount >= 3 }
        private var dashCount = 0
        private var iterator: Substring.Iterator

        static func match(_ string: Substring) -> Self {
            var instance = Self(iterator: string.makeIterator())
            while let char = instance.iterator.next() {
                if !instance.handle(char: char) {
                    break
                }
            }
            return instance
        }

        private mutating func handle(char: Character) -> Bool {
            switch char {
            case "[":
                dashCount = 0
                guard !prefix.contains("["),
                      let next = iterator.next(),
                      [" ", "x", "X"].contains(next),
                      let close = iterator.next(),
                      close == "]"
                else {
                    empty = false
                    return false
                }
                prefix.append("[ ]")
                return true
            case " ":
                prefix.append(char)
            case ">":
                prefix.append(char)
                dashCount = 0
            case "-":
                dashCount += 1
                if prefix.contains(">") {
                    prefix.append(char)
                } else {
                    prefix = "\(String(repeating: " ", count: prefix.count))-"
                }
            case "\n":
                return false
            default:
                empty = false
                return false
            }
            return true
        }
    }
}
