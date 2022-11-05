import Combine
import MarkCell
import Markdown
import Notes
import Paths
import UIKit
import UIKitPlus

class SearchController: UITableViewController, Bindable {
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
        tableView.register(MarkCell.self)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let note = notes[indexPath.row]
        return tableView.render((text: note.text, with: CellDelegate(file: note.file, controller: self)), for: indexPath) as MarkCell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
