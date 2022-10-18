import Combine
import Markdown
import UIKit

class NoteDocument: UIDocument {
    var name: Paths.File.Name
    var text: String = ""

    init(name: Paths.File.Name) {
        self.name = name
        super.init(fileURL: name.url)
    }

    override func load(fromContents contents: Any, ofType typeName: String?) throws {
        // TODO: Handle error.
        guard let data = contents as? Data,
              let text = String(data: data, encoding: .utf8) else { return }
        self.text = text.replacingOccurrences(of: "\r\n", with: "\n")
    }

    override func contents(forType typeName: String) throws -> Any {
        // TODO: Handle error.
        text.data(using: .utf8)!
    }

    override func savePresentedItemChanges() async throws {
        try await super.savePresentedItemChanges()
        Task.detached {
            await Engine.shared.update(files: [Engine.paths.locate(file: self.name)])
        }
    }
}

class NoteController: UITableViewController, Bindable, Navigator {
    enum Section {
        case note, edit, from, to
    }

    var document: NoteDocument?
    var sections: [Section] = []
    var entrySink: AnyCancellable?
    var entry: Note.Entry? {
        didSet { reload() }
    }

    // TODO: Figure out solution for navigating to a new note.
    var create = false
    lazy var edit = create {
        didSet { reload() }
    }

    lazy var menuButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: self, action: #selector(menu))

    @objc func toggleEdit() {
        edit = !edit
    }

    var id: Note.ID? {
        didSet {
            if id != oldValue {
                document = nil
            }
            guard let id = id else {
                guard let nav = navigationController else { return }
                if nav.viewControllers.count > 1 {
                    nav.popViewController(animated: true)
                } else {
                    nav.viewControllers = [NoteController()]
                }
                return
            }
            entrySink = Engine.subscribe(with(\.entry), to: Note.Entry.Load(id: id))
        }
    }

    var text: String {
        document?.text ?? entry?.text ?? ""
    }

    @objc func menu() {
        guard let id = id else { return }
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if text != "" {
            menu.addAction(UIAlertAction(title: "Share", style: .default) { _ in })
        }
        menu.addAction(UIAlertAction(title: "Delete Note", style: .destructive) { [weak self] _ in
            let confirm = UIAlertController(title: "Delete \(self?.entry?.name ?? id.name)?", message: "This operation cannot be undone.", preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            confirm.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                self?.document = nil
                let file = Engine.paths.locate(file: id.file)
                try? FileManager.default.removeItem(at: file.url)
                Engine.shared.delete(files: [file])
                self?.id = nil
            })
            self?.present(confirm, animated: true)
        })
        menu.modalPresentationStyle = .popover
        menu.popoverPresentationController?.barButtonItem = menuButton
        present(menu, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(EditCell.self)
        tableView.register(Note.Cell.self)
        tableView.register(Note.Entry.Link.Cell.self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        guard let document = document,
              document.hasUnsavedChanges else { return }
        Task.detached {
            try await document.savePresentedItemChanges()
        }
    }

    var reloading = false
    func reload() {
        title = entry?.name ?? id?.name
        guard let id = id else {
            sections = []
            tableView.reloadData()
            return
        }
        Task {
            if edit, document == nil {
                let document = NoteDocument(name: id.file)
                // TODO: Handle errors.
                if create {
                    if id.name != "" {
                        document.text = "# \(id.name)"
                    }
                    guard await document.save(to: document.fileURL, for: .forCreating) else { return }
                } else {
                    guard await document.open() else { return }
                }
                self.document = document
            } else {
                try await document?.savePresentedItemChanges()
            }
            var sections: [Section] = [edit ? .edit : .note]
            if entry?.from.count ?? 0 > 0 {
                sections.append(.from)
            }
            if entry?.to.count ?? 0 > 0 {
                sections.append(.to)
            }
            navigationItem.rightBarButtonItems = [
                menuButton,
                UIBarButtonItem(image: edit ? UIImage(systemName: "checkmark") : UIImage(systemName: "pencil"), style: .plain, target: self, action: #selector(toggleEdit)),
            ]
            DispatchQueue.main.async {
                self.reloading = true
                self.sections = sections
                self.tableView.reloadData()
                self.reloading = false
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    var date: DateFormatter {
        let date = DateFormatter()
        date.dateStyle = .short
        date.timeStyle = .short
        return date
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let entry = entry else { return nil }
        switch sections[section] {
        case .edit:
            return "Last Saved \(date.string(from: entry.note.modified))"
        case .note:
            return "Last Modified \(date.string(from: entry.note.modified))"
        case .from:
            return "Linked From"
        case .to:
            return "Linked To"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .note:
            return tableView.render(text, with: self, for: indexPath) as Note.Cell
        case .edit:
            return tableView.render(text, with: self, for: indexPath) as EditCell
        case .from:
            return tableView.render(entry!.from[indexPath.row], with: entry!.name, for: indexPath) as Note.Entry.Link.Cell
        case .to:
            return tableView.render(entry!.to[indexPath.row], with: entry!.name, for: indexPath) as Note.Entry.Link.Cell
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .note, .edit:
            return 1
        case .from:
            return entry?.from.count ?? 0
        case .to:
            return entry?.to.count ?? 0
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let dest: Note.ID
        switch sections[indexPath.section] {
        case .from:
            dest = entry!.from[indexPath.row].note
        case .to:
            dest = entry!.to[indexPath.row].note
        default:
            return
        }
        navigate(to: dest)
    }
    
    func navigate(to id: Note.ID) {
        guard let nav = navigationController else { return }
        let controller = NoteController()
        controller.edit = edit
        controller.id = id
        nav.show(controller, sender: self)
    }
}

