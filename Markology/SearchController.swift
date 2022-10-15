import Combine
import Markdown
import UIKit

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
            noteSink = Engine.subscribe(with(\.notes), to: Note.Search(query: query))
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(Note.self)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        tableView.render(notes[indexPath.row], for: indexPath)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        notes.count
    }
}
