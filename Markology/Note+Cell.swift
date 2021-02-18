import Down
import UIKit

extension Note {
    class Cell: UITableViewCell {
        static let id = "note"

        let textView = UITextView(frame: .zero)
        var navigate: ((Reference) -> Void)?

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            textView.anchored(to: contentView, horizontal: true, top: true, bottom: true)
            textView.isEditable = false
            textView.backgroundColor = .secondarySystemGroupedBackground
            textView.textContainerInset = .init(top: 15, left: 10, bottom: 15, right: 10)
            textView.linkTextAttributes = [:]
            textView.delegate = self
            textView.isScrollEnabled = false
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func render(note: Note, navigate: @escaping (Reference) -> Void) {
            self.navigate = navigate
            textView.typingAttributes = [:]
            textView.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
            guard World.shared.url(for: note.file).markdown else {
                textView.text = note.text
                return
            }
            do {
                textView.attributedText = try Down(markdownString: note.text).toAttributedString(styler: Styler.shared)
            } catch {
                textView.text = note.text
            }
        }
    }
}

extension Note.Cell: UITextViewDelegate {
    func textView(_: UITextView, shouldInteractWith url: URL, in _: NSRange, interaction _: UITextItemInteraction) -> Bool {
        guard url.host == nil else { return true }
        guard let note = World.shared.load(file: url.path) else { return false }
        navigate?(note)
        return false
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
            quoteStripe: .secondaryLabel,
            thematicBreak: .secondaryLabel,
            listItemPrefix: .label,
            codeBlockBackground: .systemGroupedBackground
        )))
    }

    override func style(link str: NSMutableAttributedString, title _: String?, url: String?) {
        styleLink(str: str, url: url)
    }

    override func style(image str: NSMutableAttributedString, title _: String?, url: String?) {
        guard let url = url else { return }
        defer { styleLink(str: str, url: url) }
        guard let path = URL(string: url), path.host == nil,
              let image = UIImage(contentsOfFile: World.shared.url(for: path.path).path) else { return }
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
            .foregroundColor: url.contains(":") || url.contains("//") ? UIColor.systemBlue : UIColor.systemTeal,
        ], range: .init(location: 0, length: str.length))
    }
}
