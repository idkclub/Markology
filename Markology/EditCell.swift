import Combine
import Markdown
import UIKit

class EditCell: NoteCell<NoteController> {
    var previous: UITextRange?
    var dirty = false
    var insertSink: AnyCancellable?

    override func config(_ controller: NoteController) {
        super.config(controller)
        markdown.isEditable = true
        markdown.commandable = controller
        insertSink = controller.addLink.sink {
            guard let selection = self.markdown.selectedTextRange,
                  let url = $0.file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }
            if selection.start == selection.end,
               let token = self.markdown.tokenizer.rangeEnclosingPosition(selection.start, with: .word, inDirection: .storage(.backward))
            {
                self.markdown.selectedTextRange = token
            }
            self.markdown.insertText("[\($0.name)](\(url))")
        }
    }

    override func render(_ text: String) {
        markdown.attributedText = EditVisitor.process(text: text)
        markdown.becomeFirstResponder()
    }

    override func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let body = textView.text,
              text == "\n",
              let indexRange = Range(range, in: body) else { return true }
        let line = body.lineRange(for: indexRange)
        var prefix = ""
        var empty = true
        var dashCount = 0
        loop: for (index, char) in body[line].enumerated() {
            switch char {
            case " ":
                prefix.append(char)
            case ">":
                prefix.append(char)
                dashCount = 0
            case "-":
                dashCount += 1
                if prefix.contains(">") {
                    prefix.append(char)
                    continue
                }
                prefix = "\(String(repeating: " ", count: index))-"
            case "\n":
                break loop
            default:
                empty = false
                break loop
            }
        }
        guard dashCount < 3 else { return true }
        if prefix != "" {
            dirty = true
            let replace: String
            let selected: Int
            let uiRange: UITextRange?
            if empty {
                let range = NSRange(line, in: body)
                replace = line.upperBound == body.endIndex ? "\n" : "\n\n"
                selected = range.lowerBound + 1
                uiRange = textView.range(for: range)
            } else {
                replace = "\n\(prefix)"
                selected = range.upperBound + 1 + prefix.count
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

    // @objc seems to be required: https://github.com/apple/swift/issues/45421
    @objc func textViewDidChange(_ textView: UITextView) {
        dirty = true
        let select = textView.selectedRange
        let text = textView.attributedText.string
        render(text)
        textView.selectedRange = select
        controller?.document?.text = text
        controller?.document?.updateChangeCount(.done)
        controller?.tableView.beginUpdates()
        controller?.tableView.endUpdates()
        dirty = false
    }

    @objc func textViewDidChangeSelection(_ textView: UITextView) {
        guard !dirty,
              let selection = textView.selectedTextRange,
              let tableView = controller?.tableView else { return }
        var position = selection.end
        if position == previous?.end {
            position = selection.start
        }
        if selection.start != selection.end,
           let text = textView.text(in: selection),
           !text.contains(where: \.isNewline)
        {
            controller?.search = text
        } else if let token = textView.tokenizer.rangeEnclosingPosition(position, with: .word, inDirection: .storage(.backward)),
                  let text = textView.text(in: token)
        {
            controller?.search = text
        }
        var rect = textView.convert(textView.caretRect(for: position), to: tableView)
        if rect.origin.y == .infinity {
            rect = convert(bounds, to: tableView)
            rect.origin.y = rect.minY + rect.height
            rect.size.height = 50
        } else {
            rect.origin.y -= rect.size.height
            rect.size.height *= 3
        }
        tableView.scrollRectToVisible(rect, animated: false)
        previous = textView.selectedTextRange
    }

    override func name(from text: String) -> String {
        let doc = Document(parsing: text)
        var visitor = LinkWalker()
        visitor.visit(doc)
        return visitor.text
    }

    struct LinkWalker: MarkupWalker {
        var text = ""
        mutating func visitLink(_ link: Markdown.Link) {
            text = link.plainText
        }
    }
}
