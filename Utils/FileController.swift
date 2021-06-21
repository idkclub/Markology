import UIKit

open class FileController: UIViewController {
    var items: [Item] = []
    var onSave: (([URL]) -> Void)?
    var saveButton: UIBarButtonItem?
    var tableView: UITableView?

    @discardableResult public func use(providers: [NSItemProvider], onSave: (([URL]) -> Void)? = nil) -> Self {
        self.onSave = onSave
        let group = DispatchGroup()
        for provider in providers {
            // Likely a screen shot editor result, not loadable as file representation.
            if provider.registeredTypeIdentifiers.first == "public.image" {
                group.enter()
                provider.loadItem(forTypeIdentifier: "public.image", options: nil) { data, error in
                    defer { group.leave() }
                    guard let data = data as? UIImage else {
                        if let error = error {
                            self.errorAlert(for: error)
                        }
                        return
                    }
                    self.items.append(Item(image: data, name: provider.suggestedName ?? ""))
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.image") {
                group.enter()
                provider.loadFileRepresentation(forTypeIdentifier: "public.image") { url, error in
                    defer { group.leave() }
                    guard let url = url else {
                        if let error = error {
                            self.errorAlert(for: error)
                        }
                        return
                    }
                    do {
                        try self.items.append(Item(url: url))
                    } catch {
                        self.errorAlert(for: error)
                    }
                }
            }
        }
        group.notify(queue: .main) {
            guard let tableView = self.tableView else { return }
            tableView.reloadData()
            self.validate()
        }
        return self
    }

    override open func viewDidLoad() {
        saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
        let tableView = UITableView(frame: .zero, style: .grouped).anchored(to: view, horizontal: true, top: true)
        self.tableView = tableView
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(Cell.self, forCellReuseIdentifier: Cell.id)
        let buttons = UIToolbar(frame: .infinite).anchored(to: view, horizontal: true)
        buttons.items = [
            .flexibleSpace(),
            saveButton!,
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel)),
        ]
        NSLayoutConstraint.activate([
            tableView.bottomAnchor.constraint(equalTo: buttons.topAnchor),
            buttons.bottomAnchor.constraint(equalTo: KeyboardGuide(view: view).topAnchor),
        ])
        validate()
    }

    @objc private func save() {
        do {
            var urls: [URL] = []
            for file in items {
                let url = file.url
                try file.save()
                urls.append(url)
            }
            dismiss(animated: true)
            onSave?(urls)
        } catch {
            errorAlert(for: error)
        }
    }

    @objc private func cancel() {
        dismiss(animated: true)
        onSave?([])
    }

    private func validate() {
        saveButton?.isEnabled = items.allSatisfy { $0.name != "" && !$0.exists } && Set(items.map { $0.name }).count == items.count
    }
}

extension FileController: UITableViewDelegate {
    public func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        return "Import Images"
    }
}

extension FileController: UITableViewDataSource {
    public func numberOfSections(in _: UITableView) -> Int {
        1
    }

    public func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        items.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FileController.Cell.id, for: indexPath) as! FileController.Cell
        cell.render(item: items[indexPath.row], validate: validate)
        return cell
    }
}

extension FileController {
    class Item {
        let source: URL?
        let image: UIImage?
        let ext: String
        var name: String

        init(url: URL) throws {
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.copyItem(at: url, to: temp)
            source = temp
            image = UIImage(contentsOfFile: temp.path)
            name = url.deletingPathExtension().lastPathComponent
            ext = url.pathExtension.lowercased()
        }

        init(image: UIImage, name: String) {
            source = nil
            self.image = image
            self.name = name
            ext = "png"
        }

        var url: URL {
            Container.url(for: name).appendingPathExtension(ext)
        }

        var exists: Bool {
            FileManager.default.fileExists(atPath: url.path)
        }

        func save() throws {
            try FileManager.default.createDirectory(atPath: url.deletingLastPathComponent().path, withIntermediateDirectories: true, attributes: nil)
            guard let source = source else {
                guard let image = image else { return }
                try image.pngData()?.write(to: url)
                return
            }
            try FileManager.default.copyItem(at: source, to: url)
            try? FileManager.default.removeItem(at: source)
        }
    }

    class Cell: UITableViewCell {
        static let id = "file"
        let preview = UIImageView()
        let textField = UITextField()
        let extField = UILabel()
        var item: Item?
        var validate: (() -> Void)?

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            preview.anchored(to: contentView, top: true, bottom: true)
            preview.contentMode = .scaleAspectFit
            textField.anchored(to: contentView, top: true, bottom: true)
            textField.placeholder = "Name"
            textField.addTarget(self, action: #selector(edit), for: .editingChanged)
            extField.anchored(to: contentView, top: true, bottom: true)
            let heightConstraint = preview.heightAnchor.constraint(equalToConstant: 150)
            heightConstraint.priority = UILayoutPriority(999)
            NSLayoutConstraint.activate([
                preview.widthAnchor.constraint(equalToConstant: 150),
                heightConstraint,
                preview.leftAnchor.constraint(equalTo: contentView.leftAnchor),
                textField.leftAnchor.constraint(equalTo: preview.rightAnchor, constant: 20),
                extField.leftAnchor.constraint(equalTo: textField.rightAnchor),
            ])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc func edit() {
            guard let item = item else { return }
            item.name = textField.text ?? ""
            validate?()
            textField.textColor = item.exists ? .systemRed : .label
        }

        func render(item: Item, validate: (() -> Void)?) {
            self.item = item
            self.validate = validate
            preview.image = item.image
            textField.text = item.name
            textField.textColor = item.exists ? .systemRed : .label
            extField.text = ".\(item.ext)"
        }
    }
}
