import UIKit

class FileController: UIViewController {
    let files: [File]
    let onSave: (([URL]) -> Void)?
    var saveButton: UIBarButtonItem?

    init(files: [UIImage], onSave: (([URL]) -> Void)? = nil) {
        self.files = files.map { File(image: $0, name: "") }
        self.onSave = onSave

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        saveButton = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
        let tableView = UITableView(frame: .zero, style: .grouped).anchored(to: view, horizontal: true, top: true)
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
            for file in files {
                let url = file.url
                try file.image.pngData()?.write(to: url)
                urls.append(url)
            }
            dismiss(animated: true)
            onSave?(urls)
        } catch {
            show(ErrorAlert(error: error), sender: self)
        }
    }

    @objc private func cancel() {
        dismiss(animated: true)
    }

    private func validate() {
        saveButton?.isEnabled = files.allSatisfy { $0.name != "" } && Set(files.map { $0.name }).count == files.count
    }
}

extension FileController: UITableViewDelegate {
    func tableView(_: UITableView, titleForHeaderInSection _: Int) -> String? {
        return "Import Images"
    }
}

extension FileController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        files.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FileController.Cell.id, for: indexPath) as! FileController.Cell
        cell.render(file: files[indexPath.row], validate: validate)
        return cell
    }
}

extension FileController {
    class File {
        let image: UIImage
        var name: String
        init(image: UIImage, name: String) {
            self.image = image
            self.name = name
        }

        var url: URL {
            World.shared.url(for: name).appendingPathExtension("png")
        }
    }

    class Cell: UITableViewCell {
        static let id = "file"
        let preview = UIImageView()
        let textField = UITextField()
        var file: File?
        var validate: (() -> Void)?

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            preview.anchored(to: contentView, top: true, bottom: true)
            preview.contentMode = .scaleAspectFit
            textField.anchored(to: contentView, top: true, bottom: true)
            textField.placeholder = "Name"
            textField.addTarget(self, action: #selector(edit), for: .editingChanged)
            NSLayoutConstraint.activate([
                preview.widthAnchor.constraint(equalToConstant: 150),
                preview.heightAnchor.constraint(equalToConstant: 150),
                preview.leftAnchor.constraint(equalTo: contentView.leftAnchor),
                textField.leftAnchor.constraint(equalTo: preview.rightAnchor, constant: 20),
            ])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc func edit() {
            guard let file = file else { return }
            file.name = textField.text ?? ""
            validate?()
            textField.textColor = FileManager.default.fileExists(atPath: file.url.path) ? .systemYellow : .label
        }

        func render(file: File, validate: (() -> Void)?) {
            self.file = file
            self.validate = validate
            preview.image = file.image
            textField.text = file.name
        }
    }
}
