import Combine
import GRDBPlus
import MarkCell
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

    class Item {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var name: String
        let ext: String

        var file: String { "\(name).\(ext)" }

        init(url: URL) throws {
            try FileManager.default.copyItem(at: url, to: temp)
            name = url.deletingPathExtension().lastPathComponent
            ext = url.pathExtension.lowercased()
        }

        init(image: UIImage, name: String) throws {
            self.name = name
            ext = "png"
            try image.pngData()?.write(to: temp)
        }
    }

    var items: [Item] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    public func load(providers: [NSItemProvider]) {
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
                            items.append(try Item(url: data))
                        case let data as UIImage:
                            items.append(try Item(image: data, name: provider.suggestedName ?? fallback))
                        case let data as Data:
                            guard let image = UIImage(data: data) else { break }
                            items.append(try Item(image: image, name: provider.suggestedName ?? fallback))
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

    override open func viewDidLoad() {
        super.viewDidLoad()
        let toolbar = UIToolbar().pinned(toKeyboardAnd: view, top: false)
        toolbar.items = [
            .flexibleSpace(),
            UIBarButtonItem(title: "Import", style: .done, target: self, action: #selector(save)),
            UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(cancel)),
        ]
        toolbar.backgroundColor = .systemBackground
        tableView.bottomAnchor.constraint(equalTo: toolbar.topAnchor).isActive = true
        if let self = self as? LinkControllerDelegate {
            linkController.delegate = self
            add(linkController)
            linkController.view.pinned(to: view, bottom: false, top: false)
            linkController.view.bottomAnchor.constraint(equalTo: toolbar.topAnchor).isActive = true
        }
    }

    @objc open func save() {
        dismiss(animated: true)
    }

    @objc open func cancel() {
        dismiss(animated: true)
    }
}

public extension ImportController {
    func adjustInset(by offset: CGFloat) {
        tableView.contentInset.bottom = offset
        tableView.verticalScrollIndicatorInsets.bottom = offset
    }
}

extension ImportController: EditCellDelegate {
    public func change(text: String) {}
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
        }

        @objc func rename() {
            guard let item = item else { return }
            item.name = name.text ?? ""
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
        switch indexPath.row {
        case 0:
            return tableView.render(items[indexPath.section].temp, for: indexPath) as FileCell
        case 1:
            return tableView.render(items[indexPath.section], for: indexPath) as ItemCell
        default:
            return tableView.render((text: "", with: self, search: linkController), for: indexPath) as EditCell
        }
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        items[section].file
    }
}
