import UIKit
import Utils

class EditController: UIViewController {
    let textView = UITextView()
    let url: URL
    let onSave: ((URL) -> Void)?
    var addLink: UIBarButtonItem?
    var text: String

    init(path: String? = nil, text: String = "", onSave: ((URL) -> Void)? = nil) {
        url = Container.url(for: path)
        self.text = text
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addLink = UIBarButtonItem(title: "Add Link", style: .plain, target: self, action: #selector(link))
        let buttons = UIToolbar(frame: .infinite).anchored(to: view, horizontal: true)
        buttons.items = [
            addLink!,
            .flexibleSpace(),
            UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save)),
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel)),
        ]
        textView.anchored(to: view, horizontal: true, top: true)
        textView.textContainerInset = .init(top: 20, left: 10, bottom: 10, right: 10)
        textView.font = .systemFont(ofSize: 17)
        textView.text = text
        textView.smartDashesType = .no
        textView.delegate = self
        let drop = UIDropInteraction(delegate: self)
        textView.addInteraction(drop)
        NSLayoutConstraint.activate([
            textView.bottomAnchor.constraint(equalTo: buttons.topAnchor),
            buttons.bottomAnchor.constraint(equalTo: KeyboardGuide(view: view).topAnchor),
        ])
        textView.becomeFirstResponder()
    }

    static func body(from query: String) -> String {
        query != "" ? "# \(query)\n\n" : ""
    }

    func onImport(urls: [URL]) {
        for url in urls {
            guard let path = Container.local(for: url).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { continue }
            textView.insertText("![](\(path))")
        }
    }

    @objc private func link() {
        var text = ""
        if let range = textView.selectedTextRange,
           let selected = textView.text(in: range)?.replacingOccurrences(of: "\n", with: " ")
        {
            text = selected
        }
        let menu = MenuController(style: .grouped, initial: text, showCancel: true, showCreateEmpty: false, delegate: self)
        menu.modalPresentationStyle = .popover
        menu.popoverPresentationController?.barButtonItem = addLink
        present(menu, animated: true)
        textView.resignFirstResponder()
    }

    @objc private func save() {
        do {
            try World.shared.write(contents: text, to: url)
            dismiss(animated: true)
            onSave?(url)
        } catch { errorAlert(for: error) }
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }
}

extension EditController: MenuDelegate {
    func select(note: Reference) {
        guard let url = note.file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }
        if ["tiff", "tif", "png", "jpg", "jpeg", "jp2", "heic", "gif", "bmp"].contains(where: { (url as NSString).pathExtension.lowercased() == $0 }) {
            textView.insertText("![](\(url))")
        } else {
            textView.insertText("[\(note.name)](\(url))")
        }
        dismiss(animated: true)
        textView.becomeFirstResponder()
    }

    func create(query: String) {
        let new = Container.url(for: nil)
        do {
            try World.shared.write(contents: EditController.body(from: query), to: new)
        } catch { errorAlert(for: error) }
        select(note: Reference(file: Container.local(for: new), name: query))
    }
}

extension EditController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        text = textView.text
    }
}

extension EditController: UIDropInteractionDelegate {
    func dropInteraction(_: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        session.hasItemsConforming(toTypeIdentifiers: ["public.image"])
    }

    func dropInteraction(_: UIDropInteraction, sessionDidUpdate _: UIDropSession) -> UIDropProposal {
        UIDropProposal(operation: .copy)
    }

    func dropInteraction(_: UIDropInteraction, performDrop session: UIDropSession) {
        present(FileController().use(providers: session.items.map { $0.itemProvider }, onSave: onImport), animated: true)
    }
}
