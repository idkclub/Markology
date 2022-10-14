import Combine
import UIKit

class MenuController: UIViewController, Bindable {
    let table = UITableView()
    var progressSink: AnyCancellable?
    var searchSink: AnyCancellable?
    var query: String = ""
    var ids: [Note.ID] = [] {
        didSet {
            table.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        searchSink = Engine.subscribe(with(\.ids), to: Note.ID.Search(text: ""))

        let progress = UIProgressView(progressViewStyle: .bar)
        progressSink = Engine.progress.sink {
            progress.progress = $0
        }

        let search = UISearchBar()
        search.placeholder = "Search or Create"
        search.delegate = self

        table.dataSource = self
        table.delegate = self
        table.register(Note.ID.self)

        let stack = UIStackView(arrangedSubviews: [progress, search, table])
            .pinned(to: view)
        stack.axis = .vertical
    }
}

extension MenuController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchSink = Engine.subscribe(with(\.ids), to: Note.ID.Search(text: searchText))
    }
}

extension MenuController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        ids.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        tableView.render(ids[indexPath.row], for: indexPath)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        "Recent"
    }
}

extension MenuController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let nav = splitViewController?.viewController(for: .secondary) as? UINavigationController else { return }
        let controller = NoteController()
        nav.viewControllers = [controller]
        controller.id = ids[indexPath.row]
    }
}
