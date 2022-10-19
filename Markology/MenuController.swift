import Combine
import UIKit

class MenuController: UIViewController, Bindable {
    enum Section {
        case notes, new
    }

    let table = UITableView()
    let search = UISearchBar()
    var sections: [Section] = []
    var progressSink: AnyCancellable?
    var searchSink: AnyCancellable?
    var query: String = ""
    var ids: [Note.ID] = [] {
        didSet { reload() }
    }

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

        search.placeholder = "Search or Create"
        search.enablesReturnKeyAutomatically = false
        search.searchBarStyle = .minimal
        search.delegate = self
        searchSink = Engine.subscribe(with(\.ids), to: Note.ID.Search(text: ""))

        let progress = UIProgressView(progressViewStyle: .bar)
        progressSink = Engine.progress.sink {
            progress.progress = $0
        }

        table.keyboardDismissMode = .onDrag
        table.dataSource = self
        table.delegate = self
        table.register(Note.ID.Cell.self)

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
            return tableView.render(ids[indexPath.row].name, for: indexPath) as Note.ID.Cell
        case .new:
            return tableView.render(search.text ?? "", for: indexPath) as Note.ID.Cell
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .notes:
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
        let controller = NoteController()
        nav.viewControllers = [controller]
        switch sections[indexPath.section] {
        case .notes:
            controller.id = ids[indexPath.row]
        case .new:
            controller.edit = true
            controller.id = Note.ID.generate(for: search.text ?? "")
        }
        split.show(.secondary)
    }
}
