import Markdown
import UIKit

class EditCell: UITableViewCell, ConfigCell {
    weak var controller: NoteController?
    var previous: UITextRange?
    var dirty = false
    lazy var markdown = {
        let markdown = TextView().pinned(to: contentView)
        markdown.isScrollEnabled = false
        markdown.isEditable = true
        markdown.textContainerInset = .init(top: 15, left: 15, bottom: 15, right: 15)
        markdown.delegate = self
        return markdown
    }()

    func config(_ controller: NoteController) {
        self.controller = controller
        markdown.controller = controller
    }

    func render(_ text: String) {
        let doc = Document(parsing: text)
        var visitor = EditVisitor(text: text)
        markdown.attributedText = visitor.visit(doc)
            .setMissing(key: .foregroundColor, value: UIColor.label)
        markdown.becomeFirstResponder()
    }
}

extension EditCell: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        guard url.host == nil else { return true }
        guard let relative = (controller?.id?.file ?? "/").use(for: url) else { return false }
        // TODO: Extract name.
        controller?.navigate(to: Note.ID(file: relative, name: ""))
        return false
    }
    
    func textViewDidChange(_ textView: UITextView) {
        dirty = true
        controller?.tableView?.beginUpdates()
        let select = textView.selectedRange
        let text = textView.attributedText.string
        render(text)
        textView.selectedRange = select
        controller?.tableView?.endUpdates()
        controller?.document?.text = text
        controller?.document?.updateChangeCount(.done)
        dirty = false
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
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
}
