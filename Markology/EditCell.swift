import Markdown
import UIKit

class EditCell: NoteCell<NoteController> {
    var previous: UITextRange?
    var dirty = false

    override func config(_ controller: NoteController) {
        super.config(controller)
        markdown.isEditable = true
    }

    override func render(_ text: String) {
        let doc = Document(parsing: text)
        var visitor = EditVisitor(text: text)
        markdown.attributedText = visitor.visit(doc)
            .setMissing(key: .foregroundColor, value: UIColor.label)
        markdown.becomeFirstResponder()
    }

    // TODO: Handle tab/shift-tab for indentation?
    override func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard let body = textView.text,
              text == "\n",
              let indexRange = Range(range, in: body) else { return true }
        let line = body.lineRange(for: indexRange)
        var prefix = ""
        var empty = true
        loop:
            for (index, char) in body[line].enumerated() {
            switch char {
            case " ", ">":
                prefix.append(char)
            case "-":
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
        if prefix != "" {
            dirty = true
            let text = textView.attributedText.mutableCopy() as! NSMutableAttributedString
            let selected: NSRange
            if empty {
                let range = NSRange(line.lowerBound.utf16Offset(in: body) ..< line.upperBound.utf16Offset(in: body))
                text.replaceCharacters(in: range, with: "\n\n")
                selected = NSRange(location: range.lowerBound + 1, length: 0)
            } else {
                text.replaceCharacters(in: range, with: "\n\(prefix)")
                selected = NSRange(location: range.upperBound + 1 + prefix.count, length: 0)
            }
            textView.attributedText = text
            textView.selectedRange = selected
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
        controller?.tableView?.beginUpdates()
        controller?.tableView?.endUpdates()
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
