import Combine
import Markdown
import UIKit

class NoteController: UITableViewController, Bindable {
    private enum Section: Equatable {
        case note, edit
        case from(Int), to(Int)

        var count: Int {
            switch self {
            case .note, .edit:
                return 1
            case let .from(count), let .to(count):
                return count
            }
        }
    }

    private(set) var document: NoteDocument?
    private var sections: [Section] = []
    private var entrySink: AnyCancellable?
    private var entry: Note.Entry? {
        didSet { reload() }
    }

    private lazy var menuButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: self, action: #selector(menu))

    var edit = false
    @objc func toggleEdit() {
        if edit {
            sync()
        }
        edit = !edit
        reload()
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
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        menu.modalPresentationStyle = .popover
        menu.popoverPresentationController?.barButtonItem = menuButton
        present(menu, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(EditCell.self)
        tableView.register(EmptyCell.self)
        tableView.register(NoteCell<Self>.self)
        tableView.register(Note.Entry.Link.Cell.self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sync()
    }

    private func sync() {
        if let id = id,
           let document = document,
           document.hasUnsavedChanges
        {
            Engine.shared.update(file: id.file, with: text)
        }
    }

    private func reload() {
        title = entry?.name ?? id?.name
        guard let id = id else { return }
        Task {
            if edit, document == nil {
                let document = NoteDocument(name: id.file)
                // TODO: Handle errors.
                if FileManager.default.fileExists(atPath: document.fileURL.path) {
                    guard await document.open() else { return }
                } else {
                    try? FileManager.default.createDirectory(at: document.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    document.text = id.name == "" ? "" : "# \(id.name)\n\n"
                    guard await document.save(to: document.fileURL, for: .forCreating) else { return }
                }
                self.document = document
            }
            var sections: [Section] = [edit ? .edit : .note]
            if let count = entry?.from.count, count > 0 {
                sections.append(.from(count))
            }
            if let count = entry?.to.count, count > 0 {
                sections.append(.to(count))
            }
            navigationItem.rightBarButtonItems = [
                menuButton,
                UIBarButtonItem(image: edit ? UIImage(systemName: "checkmark") : UIImage(systemName: "pencil"), style: .plain, target: self, action: #selector(toggleEdit)),
            ]
            let last = self.sections
            self.sections = sections
            self.tableView.beginUpdates()
            if last.count > sections.count {
                self.tableView.deleteSections(IndexSet(integersIn: sections.count ..< last.count), with: .automatic)
            } else if sections.count > last.count {
                self.tableView.insertSections(IndexSet(integersIn: last.count ..< sections.count), with: .fade)
            }
            for (index, section) in sections.enumerated() {
                if index >= last.count {
                    self.tableView.insertRows(at: (0 ..< section.count).map { IndexPath(row: $0, section: index) }, with: .middle)
                    continue
                }
                if section.count > last[index].count {
                    self.tableView.insertRows(at: (last[index].count ..< section.count).map { IndexPath(row: $0, section: index) }, with: .automatic)
                } else if section.count < last[index].count {
                    self.tableView.deleteRows(at: (section.count ..< last[index].count).map { IndexPath(row: $0, section: index) }, with: .automatic)
                }
                if section != last[index] {
                    self.tableView.reloadRows(at: (0 ..< min(section.count, last[index].count)).map { IndexPath(row: $0, section: index) }, with: .fade)
                } else if section != .edit {
                    self.tableView.reloadRows(at: (0 ..< min(section.count, last[index].count)).map { IndexPath(row: $0, section: index) }, with: .none)
                }
            }
            self.tableView.endUpdates()
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    private var date: DateFormatter {
        let date = DateFormatter()
        date.dateStyle = .short
        date.timeStyle = .short
        return date
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let entry = entry else { return nil }
        switch sections[section] {
        case .edit, .note:
            return "Last Updated \(date.string(from: entry.note.modified))"
        case .from:
            return "Linked From"
        case .to:
            return "Linked To"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .note:
            if entry == nil, document == nil {
                return tableView.render(id!.file, for: indexPath) as EmptyCell
            }
            return tableView.render(NoteCell.Value(file: id!.file, text: text), with: self, for: indexPath) as NoteCell
        case .edit:
            return tableView.render(NoteCell.Value(file: id!.file, text: text), with: self, for: indexPath) as EditCell
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
}

extension NoteController {
    class EmptyCell: UITableViewCell, TableCell {
        func render(_ file: Paths.File.Name) {
            var content = defaultContentConfiguration()
            content.text = "\(file.dropFirst()) wasn't found. Begin editing to create it."
            content.textProperties.color = .placeholderText
            content.textProperties.alignment = .center
            contentConfiguration = content
        }
    }
}

extension NoteController: Navigator {
    func navigate(to id: Note.ID) {
        guard let nav = navigationController else { return }
        let controller = NoteController()
        nav.show(controller, sender: self)
        controller.edit = edit
        controller.id = id
    }
}
