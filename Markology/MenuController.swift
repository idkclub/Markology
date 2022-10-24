import Combine
import UIKit

class MenuController: UIViewController, Bindable {
    enum Section {
        case notes, new
    }

    var sections: [Section] = []
    var progressSink: AnyCancellable?
    var searchSink: AnyCancellable?
    var query: Note.ID.Search? {
        didSet {
            guard let query = query else {
                searchSink = nil
                return
            }
            searchSink = Engine.subscribe(with(\.ids), to: query)
        }
    }

    var ids: [Note.ID] = [] {
        didSet { reload() }
    }

    lazy var search: UISearchBar = {
        let search = UISearchBar()
        search.placeholder = "Search or Create"
        search.enablesReturnKeyAutomatically = false
        search.searchBarStyle = .minimal
        search.delegate = self
        return search
    }()

    lazy var table: UITableView = {
        let table = UITableView()
        table.keyboardDismissMode = .onDrag
        table.dataSource = self
        table.delegate = self
        table.register(Note.ID.Cell.self)
        return table
    }()

    func reload() {
        sections = []
        if ids.count > 0 {
            sections.append(.notes)
        }
        sections.append(.new)
        table.reloadData()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(settings))
        query = Note.ID.Search(text: "")
        let progress = UIProgressView(progressViewStyle: .bar)
        progressSink = Engine.progress.sink {
            progress.progress = $0
        }
        let stack = UIStackView(arrangedSubviews: [search, progress, table])
            .pinned(to: view)
        stack.axis = .vertical
    }

    @objc func settings() {
        show(SettingsController(), sender: self)
    }
}

extension MenuController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        query = Note.ID.Search(text: searchText)
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
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .notes:
            return ids.count
        case .new:
            return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .notes:
            return tableView.render(ids[indexPath.row], for: indexPath) as Note.ID.Cell
        case .new:
            let id = Note.ID(file: "", name: search.text ?? "")
            return tableView.render(id, for: indexPath) as Note.ID.Cell
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .notes:
            if query?.pattern != nil {
                return "Related"
            }
            return "Recent"
        case .new:
            return "New"
        }
    }
}

extension MenuController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let split = splitViewController,
              let nav = split.viewController(for: .secondary) as? UINavigationController else { return }
        let controller: NoteController
        switch sections[indexPath.section] {
        case .notes:
            controller = .with(id: ids[indexPath.row])
        case .new:
            controller = .with(id: Note.ID.generate(for: search.text ?? ""), edit: true)
        }
        nav.viewControllers = [controller]
        split.show(.secondary)
    }
}
