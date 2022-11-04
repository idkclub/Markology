import KitPlus
import Markdown
import MarkView
import UIKit

class NoteCell<N: Navigator>: UITableViewCell, UITextViewDelegate {
    weak var controller: N?
    lazy var markdown = markView()
    var file: Paths.File.Name = "/"

    func markView() -> MarkView {
        let view = MarkView().pinned(to: contentView)
        view.textContainerInset = .padded
        view.isScrollEnabled = false
        view.isEditable = false
        view.dataDetectorTypes = .all
        view.delegate = self
        return view
    }

    func render(_ text: String) {
        markdown.linkCheckboxes = controller is NoteController
        markdown.resolver = self
        markdown.render(text: text, includingMarkup: false)
    }

    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if url.scheme == MarkView.checkboxScheme {
            if let host = url.host, let line = Int(host) {
                controller?.toggleCheckbox(at: line)
            }
            return false
        }
        guard url.host == nil else { return true }
        guard let relative = file.use(forEncoded: url.path) else { return false }
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

extension NoteCell: PathResolver {
    func resolve(path: String) -> String? {
        guard let relative = file.use(forEncoded: path) else { return nil }
        return relative.url.path.removingPercentEncoding
    }
}

extension NoteCell: RenderCell {
    struct Value {
        let file: Paths.File.Name
        let text: String
        let with: N
    }

    static func value(for note: Note, with: N) -> Value {
        return Value(file: note.file, text: note.text, with: with)
    }

    func render(_ value: Value) {
        controller = value.with
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
