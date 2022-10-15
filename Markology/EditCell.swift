import Markdown
import UIKit

class EditCell: UITableViewCell, ConfigCell {
    weak var tableView: UITableView?
    var previous: UITextRange?
    var dirty = false
    lazy var markdown = {
        let markdown = NoteView().pinned(to: contentView)
        markdown.isScrollEnabled = false
        markdown.isEditable = true
        markdown.textContainerInset = .init(top: 15, left: 15, bottom: 15, right: 15)
        markdown.delegate = self
        return markdown
    }()

    func config(_ tableView: UITableView) {
        self.tableView = tableView
    }

    func render(_ note: Note) {
        render(text: note.text)
    }

    func render(text: String) {
        let doc = Document(parsing: text)
        var visitor = EditVisitor(text: text)
        markdown.attributedText = visitor.visit(doc)
            .setMissing(key: .foregroundColor, value: UIColor.label)
        markdown.becomeFirstResponder()
    }
}

extension EditCell: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        dirty = true
        tableView?.beginUpdates()
        let select = textView.selectedRange
        render(text: textView.attributedText.string)
        textView.selectedRange = select
        tableView?.endUpdates()
        dirty = false
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard !dirty,
              let selection = textView.selectedTextRange,
              let tableView = tableView else { return }
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
