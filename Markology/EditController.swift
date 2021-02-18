import UIKit

class EditController: UIViewController {
    let textView = UITextView()
    let url: URL
    let onSave: ((URL) -> Void)?
    var addLink: UIBarButtonItem?
    var text: String

    init(path: String? = nil, text: String = "", onSave: ((URL) -> Void)? = nil) {
        url = World.shared.url(for: path)
        self.text = text
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        addLink = UIBarButtonItem(title: "Add Link", style: .plain, target: self, action: #selector(link))
        let buttons = UIToolbar(frame: .infinite).anchored(to: view, horizontal: true, bottom: true)
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
        textView.bottomAnchor.constraint(equalTo: buttons.topAnchor).isActive = true
        textView.delegate = self
    }

    static func body(from query: String) -> String {
        query != "" ? "# \(query)\n\n" : ""
    }

    @objc private func link() {
        let menu = MenuController(style: .grouped, emptyCreate: false, delegate: self)
        menu.modalPresentationStyle = .popover
        menu.popoverPresentationController?.barButtonItem = addLink
        present(menu, animated: true)
    }

    @objc private func save() {
        World.shared.write(contents: text, to: url)
        dismiss(animated: true)
        onSave?(url)
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }
}

extension EditController: MenuDelegate {
    func select(note: Reference) {
        guard let url = note.file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }
        textView.insertText("[\(note.name)](\(url))")
        dismiss(animated: true)
    }

    func create(query: String) {
        let new = World.shared.url(for: nil)
        World.shared.write(contents: EditController.body(from: query), to: new)
        select(note: Reference(file: World.shared.local(for: new), name: query))
    }
}

extension EditController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        text = textView.text
    }
}
