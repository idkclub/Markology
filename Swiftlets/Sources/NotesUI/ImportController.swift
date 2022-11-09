import Combine
import GRDBPlus
import MarkCell
import Markdown
import UIKit
import UIKitPlus

open class ImportController: UIViewController {
    lazy var tableView = {
        let view = UITableView().pinned(to: self.view, bottom: false)
        view.register(FileCell.self)
        view.register(ItemCell.self)
        view.register(EditCell.self)
        view.dataSource = self
        return view
    }()

    let linkController = LinkController()
    public var delegate: ImportControllerDelegate? {
        didSet {
            linkController.delegate = delegate
        }
    }

    class Item {
        lazy var temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
        var name: String
        var text: String = ""
        let ext: String
        let delegate: ImportControllerDelegate

        var file: String { "\(name).\(ext)" }
        var exists: Bool {
            delegate.exists(file: file)
        }

        var url: URL {
            delegate.url(file: file)
        }

        init(delegate: ImportControllerDelegate, url: URL) throws {
            self.delegate = delegate
            name = url.deletingPathExtension().lastPathComponent
            ext = url.pathExtension.lowercased()
            try FileManager.default.copyItem(at: url, to: temp)
        }

        init(delegate: ImportControllerDelegate, image: UIImage, name: String) throws {
            self.delegate = delegate
            self.name = name
            ext = "png"
            try image.pngData()?.write(to: temp)
        }

        func save() throws {
            try FileManager.default.moveItem(at: temp, to: url)
            if !text.isEmpty {
                try text.write(to: url.appendingPathExtension("md"), atomically: true, encoding: .utf8)
            }
        }
    }

    var items: [Item] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    public func load(providers: [NSItemProvider]) {
        guard let delegate = delegate else { return }
        let group = DispatchGroup()
        var items: [Item] = []
        for (id, provider) in providers.enumerated() {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                group.enter()
                provider.loadItem(forTypeIdentifier: "public.image", options: nil) { data, error in
                    defer { group.leave() }
                    if let error = error {
                        self.alert(error: error)
                        return
                    }
                    let fallback = "\(Int(Date().timeIntervalSince1970).description).\(id)"
                    do {
                        switch data {
                        case let data as URL:
                            items.append(try Item(delegate: delegate, url: data))
                        case let data as UIImage:
                            items.append(try Item(delegate: delegate, image: data, name: provider.suggestedName ?? fallback))
                        case let data as Data:
                            guard let image = UIImage(data: data) else { break }
                            items.append(try Item(delegate: delegate, image: image, name: provider.suggestedName ?? fallback))
                        default:
                            break
                        }
                    } catch {
                        self.alert(error: error)
                    }
                }
            }
        }
        group.notify(queue: .main) {
            self.items = items
        }
    }

    lazy var importButton = UIBarButtonItem(title: "Import", style: .done, target: self, action: #selector(save))

    override open func viewDidLoad() {
        super.viewDidLoad()
        let toolbar = UIToolbar().pinned(toKeyboardAnd: view, top: false)
        toolbar.items = [
            .flexibleSpace(),
            importButton,
            UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancel)),
        ]
        toolbar.backgroundColor = .systemBackground
        tableView.bottomAnchor.constraint(equalTo: toolbar.topAnchor).isActive = true
        add(linkController)
        linkController.view.pinned(to: view, bottom: false, top: false)
        linkController.view.bottomAnchor.constraint(equalTo: toolbar.topAnchor).isActive = true
    }

    @objc func save() {
        do {
            try items.forEach { try $0.save() }
        } catch {
            alert(error: error)
        }
        dismiss(animated: true)
        delegate?.dismiss(importing: items.map {
            let url = "/\($0.file)"
            guard !$0.text.isEmpty else { return (url: url, text: $0.file) }
            let doc = Document(parsing: $0.text)
            var walk = NoteWalker(from: "/\($0.file)")
            walk.visit(doc)
            return (url: url, text: walk.name)
        })
    }

    @objc func cancel() {
        try? items.forEach {
            try FileManager.default.removeItem(at: $0.temp)
        }
        dismiss(animated: true)
        delegate?.dismiss(importing: [])
    }
}

extension ImportController.Item: EditCellDelegate {
    func change(text: String) {
        self.text = text
    }
}

public protocol ImportControllerDelegate: LinkControllerDelegate {
    func exists(file: String) -> Bool
    func url(file: String) -> URL
    func validate()
    func dismiss(importing: [(url: String, text: String)])
}

public extension ImportControllerDelegate {
    func exists(file: String) -> Bool {
        return FileManager.default.fileExists(atPath: url(file: file).path)
    }
}

public extension ImportController {
    func adjustInset(by offset: CGFloat) {
        tableView.contentInset.bottom = offset
        tableView.verticalScrollIndicatorInsets.bottom = offset
    }

    func validate() {
        importButton.isEnabled = items.allSatisfy { $0.name != "" && !$0.exists } && Set(items.map { $0.name }).count == items.count
    }
}

extension ImportController {
    class ItemCell: UITableViewCell, RenderCell {
        lazy var name = {
            let field = UITextField().pinned(to: contentView, trailing: false, layout: true)
            field.trailingAnchor.constraint(equalTo: ext.leadingAnchor).isActive = true
            field.textAlignment = NSTextAlignment.right
            field.addTarget(self, action: #selector(rename), for: .editingChanged)
            return field
        }()

        lazy var ext = {
            // TODO: See if can keep from being pushed offscreen.
            let label = UILabel().pinned(to: contentView, leading: false, layout: true)
            label.textColor = .secondaryLabel
            return label
        }()

        var item: Item?
        func render(_ item: Item) {
            name.text = item.name
            ext.text = ".\(item.ext)"
            self.item = item
            rename()
        }

        var exists: Bool {
            item?.exists ?? false
        }

        @objc func rename() {
            guard let item = item else { return }
            item.name = name.text ?? ""
            name.textColor = exists ? .systemRed : .label
            item.delegate.validate()
        }
    }
}

extension ImportController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        items.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        3
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = items[indexPath.section]
        switch indexPath.row {
        case 0:
            return tableView.render((url: item.temp, parent: self), for: indexPath) as FileCell
        case 1:
            return tableView.render(item, for: indexPath) as ItemCell
        default:
            return tableView.render((text: item.text, with: item, search: linkController), for: indexPath) as EditCell
        }
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        items[section].file
    }
}
