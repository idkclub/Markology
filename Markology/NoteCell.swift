import Markdown
import UIKit

class NoteCell<N: Navigator>: UITableViewCell, UITextViewDelegate, ConfigCell {
    struct Value {
        let file: Paths.File.Name
        let text: String
    }

    static func value(for note: Note) -> Value {
        return Value(file: note.file, text: note.text)
    }

    weak var controller: N?
    lazy var markdown = {
        let markdown = TextView().pinned(to: contentView)
        markdown.isScrollEnabled = false
        markdown.isEditable = false
        markdown.textContainerInset = .init(top: 15, left: 15, bottom: 15, right: 15)
        markdown.delegate = self
        return markdown
    }()

    var file: Paths.File.Name = "/"

    func config(_ controller: N) {
        self.controller = controller
    }

    func render(_ value: Value) {
        file = value.file
        render(value.text)
    }

    func render(_ text: String) {
        let doc = Document(parsing: text)
        var visitor = NoteVisitor()
        markdown.attributedText = visitor.visit(doc)
            .setMissing(key: .foregroundColor, value: UIColor.label)
    }

    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        guard url.host == nil else { return true }
        guard let relative = file.use(for: url) else { return false }
        var name = ""
        if let start = textView.position(from: textView.beginningOfDocument, offset: characterRange.location),
           let end = textView.position(from: start, offset: characterRange.length),
           let range = textView.textRange(from: start, to: end),
           let text = textView.text(in: range)
        {
            name = self.name(from: text)
        }
        // TODO: Extract name.
        controller?.navigate(to: Note.ID(file: relative, name: name))
        return false
    }

    func name(from text: String) -> String {
        text
    }
}

protocol Navigator: NSObject {
    func navigate(to id: Note.ID)
}

extension Navigator where Self: UIViewController {
    func navigate(to id: Note.ID) {
        guard let nav = navigationController else { return }
        let controller = NoteController()
        nav.show(controller, sender: self)
        controller.id = id
    }
}
