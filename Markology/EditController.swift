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
        textView.delegate = self
        let drop = UIDropInteraction(delegate: self)
        textView.addInteraction(drop)
        NSLayoutConstraint.activate([
            textView.bottomAnchor.constraint(equalTo: buttons.topAnchor),
            buttons.bottomAnchor.constraint(equalTo: KeyboardGuide(view: view).topAnchor),
        ])
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
        let menu = MenuController(style: .grouped, emptyCreate: false, delegate: self)
        menu.modalPresentationStyle = .popover
        menu.popoverPresentationController?.barButtonItem = addLink
        present(menu, animated: true)
    }

    @objc private func save() {
        do {
            try World.shared.write(contents: text, to: url)
        } catch { errorAlert(for: error) }
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
        session.canLoadObjects(ofClass: UIImage.self)
    }

    func dropInteraction(_: UIDropInteraction, sessionDidUpdate _: UIDropSession) -> UIDropProposal {
        UIDropProposal(operation: .copy)
    }

    func dropInteraction(_: UIDropInteraction, performDrop session: UIDropSession) {
        session.loadObjects(ofClass: UIImage.self) {
            guard let images = $0 as? [UIImage], images.count > 0 else { return }
            self.present(FileController().with(files: images, onSave: self.onImport), animated: true)
        }
    }
}
