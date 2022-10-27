import Markdown
import UIKit

class NoteCell<N: Navigator>: UITableViewCell, UITextViewDelegate {
    weak var controller: N?
    lazy var markdown = {
        let markdown = TextView().pinned(to: contentView)
        markdown.textContainerInset = .padded
        markdown.isScrollEnabled = false
        markdown.isEditable = false
        markdown.dataDetectorTypes = .all
        markdown.delegate = self
        return markdown
    }()

    var file: Paths.File.Name = "/"

    func config(_ controller: N) {
        self.controller = controller
    }

    func render(_ text: String) {
        markdown.attributedText = NoteVisitor.process(markup: Document(parsing: text), checkbox: controller is NoteController)
    }

    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if url.scheme == NoteVisitor.checkbox {
            if let host = url.host, let line = Int(host) {
                controller?.toggleCheckbox(at: line)
            }
            return false
        }
        guard url.host == nil else { return true }
        guard let path = url.path.removingPercentEncoding,
              let relative = file.use(for: path) else { return false }
        var name = ""
        if let range = textView.range(for: characterRange),
           let text = textView.text(in: range)
        {
            name = self.name(from: text)
        }
        controller?.navigate(to: Note.ID(file: relative, name: name))
        return false
    }

    func name(from text: String) -> String {
        text
    }

    // TODO: Remove this if possible without breaking EditCell (or file bug?).
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        true
    }
}

extension NoteCell: ConfigCell {
    struct Value {
        let file: Paths.File.Name
        let text: String
    }

    static func value(for note: Note) -> Value {
        return Value(file: note.file, text: note.text)
    }

    func render(_ value: Value) {
        file = value.file
        render(value.text)
    }
}

protocol Navigator: NSObject {
    func navigate(to id: Note.ID)
    func toggleCheckbox(at line: Int)
}

extension Navigator where Self: UIViewController {
    func navigate(to id: Note.ID) {
        guard let nav = navigationController else { return }
        nav.show(NoteController.with(id: id), sender: self)
    }

    func toggleCheckbox(at line: Int) {}
}
