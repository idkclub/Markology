import Combine
import Markdown
import UIKit

class SearchController: UITableViewController, Bindable, Navigator {
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
            noteSink = Engine.subscribe(with(\.notes), to: Note.Search(text: query))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(NoteCell<Self>.self)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        tableView.render(NoteCell.value(for: notes[indexPath.row], with: self), for: indexPath) as NoteCell
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        notes.count
    }
}
