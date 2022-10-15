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
        let search = UISearchBar()
        search.placeholder = "Search or Create"
        search.enablesReturnKeyAutomatically = false
        search.searchBarStyle = .minimal
        search.delegate = self
        searchSink = Engine.subscribe(with(\.ids), to: Note.ID.Search(text: ""))

        let progress = UIProgressView(progressViewStyle: .bar)
        progressSink = Engine.progress.sink {
            progress.progress = $0
        }

        table.dataSource = self
        table.delegate = self
        table.register(Note.ID.self)

        let stack = UIStackView(arrangedSubviews: [search, progress, table])
            .pinned(to: view)
        stack.axis = .vertical
    }
}

extension MenuController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchSink = Engine.subscribe(with(\.ids), to: Note.ID.Search(text: searchText))
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let split = splitViewController,
              let nav = split.viewController(for: .secondary) as? UINavigationController else { return }
        let controller = SearchController()
        nav.viewControllers = [controller]
        controller.query = searchBar.text ?? ""
        split.show(.secondary)
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
        guard let split = splitViewController,
              let nav = split.viewController(for: .secondary) as? UINavigationController else { return }
        let controller = NoteController()
        controller.id = ids[indexPath.row]
        nav.viewControllers = [controller]
        split.show(.secondary)
    }
}
