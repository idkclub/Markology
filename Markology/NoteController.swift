import Combine
import Markdown
import UIKit

class NoteController: UITableViewController, Bindable {
    enum Section {
        case note, edit, from, to
    }

    var sections: [Section] = []
    var entrySink: AnyCancellable?
    var entry: Note.Entry? {
        didSet {
            defer { tableView.reloadData() }
            title = entry?.name
            sections = []
            guard let entry = entry else { return }
            sections.append(edit ? .edit : .note)
            if entry.from.count > 0 {
                sections.append(.from)
            }
            if entry.to.count > 0 {
                sections.append(.to)
            }
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "pencil"), style: .plain, target: self, action: #selector(toggleEdit))
        }
    }

    var edit = false {
        didSet {
            defer { tableView.reloadData() }
            sections = sections.map {
                switch $0 {
                case .note, .edit:
                    return edit ? .edit : .note
                default:
                    return $0
                }
            }
        }
    }

    @objc func toggleEdit() {
        edit = !edit
    }

    var id: Note.ID? {
        didSet {
            navigationItem.rightBarButtonItem = nil
            entry = nil
            guard let id = id else {
                entrySink = nil
                return
            }
            entrySink = Engine.subscribe(with(\.entry), to: Note.Entry.Load(id: id))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(Note.self)
        tableView.register(Note.Entry.Link.self)
        tableView.register(EditCell.self)
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
        switch sections[section] {
        case .note, .edit:
            return "Last Modified \(date.string(from: entry!.note.modified))"
        case .from:
            return "Linked From"
        case .to:
            return "Linked To"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .note:
            return tableView.render(entry!.note, for: indexPath)
        case .edit:
            return tableView.render(entry!.note, with: tableView, for: indexPath) as EditCell
        case .from:
            return tableView.render(entry!.from[indexPath.row], with: entry!.name, for: indexPath)
        case .to:
            return tableView.render(entry!.to[indexPath.row], with: entry!.name, for: indexPath)
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
        guard let split = splitViewController,
              let nav = split.viewController(for: .secondary) as? UINavigationController else { return }
        let controller = NoteController()
        controller.edit = edit
        controller.id = dest
        nav.show(controller, sender: self)
        split.show(.secondary)
    }
}
