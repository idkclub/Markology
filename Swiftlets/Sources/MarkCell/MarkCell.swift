import MarkView
import UIKit
import UIKitPlus

public class MarkCell: UITableViewCell {
    var delegate: MarkCellDelegate?

    lazy var markdown = {
        let view = MarkView().pinned(to: contentView, layout: true)
        view.isScrollEnabled = false
        view.isEditable = false
        view.dataDetectorTypes = .all
        view.delegate = self
        return view
    }()

    func render(_ text: String) {
        markdown.linkCheckboxes = delegate is CheckboxDelegate
        markdown.resolver = delegate
        markdown.render(text: text, includingMarkup: false)
    }
}

extension MarkCell: RenderCell {
    public typealias Value = (text: String, with: MarkCellDelegate)
    public func render(_ value: Value) {
        delegate = value.with
        render(value.text)
    }
}

extension MarkCell: UITextViewDelegate {
    public func textView(_ textView: UITextView, shouldInteractWith url: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
        if url.scheme == MarkView.checkboxScheme {
            if let host = url.host,
               let line = Int(host),
               let delegate = delegate as? CheckboxDelegate
            {
                delegate.checkboxToggled(at: line)
            }
            return false
        }
        guard let range = textView.range(for: characterRange),
              let text = textView.text(in: range) else { return false }
        return delegate?.openLink(to: url, with: text) ?? false
    }
}

public protocol LinkDelegate {
    func openLink(to url: URL, with text: String) -> Bool
}

public protocol CheckboxDelegate {
    func checkboxToggled(at line: Int)
}

public protocol MarkCellDelegate: LinkDelegate, PathResolver {}
