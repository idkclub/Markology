import Combine
import MarkCell
import Markdown
import Notes
import Paths
import UIKit
import UIKitPlus

class SearchController: UITableViewController, Bindable {
    enum Section {
        case link, file, note
    }

    func sections(for note: Note) -> [Section] {
        var sections: [Section] = [.link]
        if !note.file.isMarkdown {
            sections.append(.file)
        }
        if !note.text.isEmpty {
            sections.append(.note)
        }
        return sections
    }

    var noteSink: AnyCancellable?
    var notes: [Note] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    var query: String? {
        didSet {
            notes = []
            guard let query = query else {
                noteSink = nil
                return
            }
            title = "Results for \"\(query)\""
            noteSink = Engine.shared.subscribe(with(\.notes), to: Note.search(text: query))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(ID.Cell.self)
        tableView.register(FileCell.self)
        tableView.register(MarkCell.self)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let note = notes[indexPath.section]
        guard let nav = navigationController else { return }
        nav.show(NoteController.with(id: note.id), sender: self)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let note = notes[indexPath.section]
        let sections = sections(for: note)
        switch sections[indexPath.row] {
        case .link:
            return tableView.render(note.id, for: indexPath) as ID.Cell
        case .file:
            return tableView.render((url: note.file.url, parent: self), for: indexPath) as FileCell
        case .note:
            return tableView.render((text: note.text, with: CellDelegate(file: note.file, controller: self)), for: indexPath) as MarkCell
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections(for: notes[section]).count
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        notes.count
    }

    class CellDelegate: MarkCellDelegate {
        var file: File.Name
        var controller: UIViewController

        init(file: File.Name, controller: UIViewController) {
            self.file = file
            self.controller = controller
        }

        func openLink(to url: URL, with text: String) -> Bool {
            guard url.host == nil else { return true }
            guard let relative = file.use(forEncoded: url.path),
                  let nav = controller.navigationController else { return false }
            nav.show(NoteController.with(id: ID(file: relative, name: text)), sender: self)
            return false
        }

        func resolve(path: String) -> String? {
            guard let relative = file.use(forEncoded: path) else { return nil }
            return relative.url.path.removingPercentEncoding
        }
    }
}
