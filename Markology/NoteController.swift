import Combine
import Markdown
import UIKit

class NoteController: UITableViewController, Bindable {
    var noteSink: AnyCancellable?
    var note: Note? {
        didSet {
            title = note?.name
            tableView.reloadData()
        }
    }

    var id: Note.ID? {
        didSet {
            note = nil
            guard let id = id else {
                noteSink = nil
                return
            }
            noteSink = Engine.subscribe(with(\.note), to: Note.Load(id: id))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(Note.self)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.render(note, for: indexPath) as! Note.Cell
        cell.markdown.tableView = tableView
        return cell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        note != nil ? 1 : 0
    }
}
