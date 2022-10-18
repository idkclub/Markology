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
