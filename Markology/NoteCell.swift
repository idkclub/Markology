import Down
import UIKit
import Utils

class NoteCell: UITableViewCell {
    static let id = "note"

    let textView = DownTextView(frame: .zero, styler: Styler.shared)
    var delegate: NoteDelegate?
    var note: Note?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        textView.anchored(to: contentView, horizontal: true, top: true, bottom: true)
        textView.isEditable = false
        textView.backgroundColor = .secondarySystemGroupedBackground
        textView.textContainerInset = .init(top: 15, left: 10, bottom: 15, right: 10)
        textView.linkTextAttributes = [:]
        textView.delegate = self
        textView.isScrollEnabled = false
        textView.dataDetectorTypes = .all
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(note: Note, delegate: NoteDelegate) {
        self.note = note
        self.delegate = delegate
        guard Container.url(for: note.file).isMarkdown else {
            textView.attributedText = NSAttributedString(string: note.text, attributes: [
                .foregroundColor: UIColor.label,
                .font: UIFont.monospacedSystemFont(ofSize: 16, weight: .regular),
            ])
            return
        }
        textView.text = note.text
    }
}

extension NoteCell: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction _: UITextItemInteraction) -> Bool {
        guard url.host == nil else { return true }
        guard let relative = URL(string: url.path, relativeTo: URL(string: note?.file ?? "/"))?.path.removingPercentEncoding else { return false }
        guard let note = World.shared.load(file: relative) else {
            guard Container.url(for: relative).isMarkdown,
                  let name = textView.attributedText?.attributedSubstring(from: characterRange).string else { return false }
            delegate?.create(path: relative, name: name)
            return false
        }
        delegate?.navigate(to: note)
        return false
    }
}

protocol NoteDelegate {
    func create(path: String, name: String) -> Void
    func navigate(to note: Reference) -> Void
}

extension UIViewController: NoteDelegate {
    func create(path: String, name: String = "") {
        present(EditController(path: path, text: EditController.body(from: name)), animated: true)
    }

    func navigate(to note: Reference) {
        show(NoteDetailController(note: note), sender: self)
    }
}

private class Styler: DownStyler {
    static let shared = Styler()
    private let urlCharacters = CharacterSet(charactersIn: ":?@#").union(.urlPathAllowed)
    init() {
        super.init(configuration: DownStylerConfiguration(colors: StaticColorCollection(
            heading1: .label,
            heading2: .label,
            heading3: .label,
            heading4: .label,
            heading5: .label,
            heading6: .label,
            body: .label,
            code: .label,
            link: .systemBlue,
            quote: .secondaryLabel,
            quoteStripe: .systemFill,
            thematicBreak: .label,
            listItemPrefix: .label,
            codeBlockBackground: .systemGroupedBackground
        )))
    }

    override func style(heading str: NSMutableAttributedString, level: Int) {
        str.enumerateAttribute(.font, in: .init(location: 0, length: str.length), options: []) { value, range, _ in
            if let value = value as? DownFont {
                var traits = value.fontDescriptor.symbolicTraits
                traits.insert(.traitBold)
                str.addAttribute(.font, value: UIFont(descriptor: value.fontDescriptor.withSymbolicTraits(traits) ?? value.fontDescriptor, size: headingSize(for: level)), range: range)
            }
        }
        str.addAttributes([
            .paragraphStyle: paragraphStyles.heading1,
        ], range: .init(location: 0, length: str.length))
    }

    override func style(link str: NSMutableAttributedString, title _: String?, url: String?) {
        styleLink(str: str, url: url)
    }

    override func style(image str: NSMutableAttributedString, title _: String?, url: String?) {
        guard let url = url else { return }
        defer { styleLink(str: str, url: url) }
        guard let path = URL(string: url), path.host == nil,
              let image = UIImage(contentsOfFile: Container.url(for: path.path).path) else { return }
        let attachment = NSTextAttachment()
        attachment.image = image
        if image.size.width < image.size.height {
            let ratio = image.size.width / image.size.height
            attachment.bounds = CGRect(x: 0, y: -90, width: ratio * 200, height: 200)
        } else {
            let ratio = image.size.height / image.size.width
            let height = ratio * 200
            attachment.bounds = CGRect(x: 0, y: -height / 2 + 10, width: 200, height: height)
        }
        str.insert(NSAttributedString(attachment: attachment), at: 0)
    }

    func styleLink(str: NSMutableAttributedString, url: String?) {
        guard let url = url?.addingPercentEncoding(withAllowedCharacters: urlCharacters) else { return }
        str.addAttributes([
            .link: url,
            .foregroundColor: url.contains(":") || url.contains("//") ? UIColor.idkCyan : UIColor.idkMagenta,
        ], range: .init(location: 0, length: str.length))
    }

    private func headingSize(for level: Int) -> CGFloat {
        switch level {
        case 1: return fonts.heading1.pointSize
        case 2: return fonts.heading2.pointSize
        case 3: return fonts.heading3.pointSize
        case 4: return fonts.heading4.pointSize
        case 5: return fonts.heading5.pointSize
        case 6: return fonts.heading6.pointSize
        default: return fonts.heading1.pointSize
        }
    }
}
