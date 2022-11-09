import Combine
import Notes
import NotesUI
import UIKit
import UIKitPlus

class MenuController: UIViewController, Bindable {
    var progressSink: AnyCancellable?
    var searchSink: AnyCancellable?
    var query: ID.Search? {
        didSet {
            guard let query = query else {
                searchSink = nil
                return
            }
            searchSink = Engine.shared.subscribe(with(\.ids), to: query)
        }
    }

    var ids: [ID] = [] {
        didSet { snapshot() }
    }

    lazy var search: UISearchBar = {
        let search = UISearchBar()
        search.placeholder = "Search or Create"
        search.enablesReturnKeyAutomatically = false
        search.searchBarStyle = .minimal
        search.delegate = self
        return search
    }()

    lazy var tableView: UITableView = {
        let table = UITableView()
        table.keyboardDismissMode = .onDrag
        table.delegate = self
        table.register(header: TappableHeader.self)
        table.register(ID.Cell.self)
        return table
    }()

    class DataSource: FadingTableSource<LinkSection, ID> {
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            switch sectionIdentifier(for: section) {
            case let .notes(valid, limited):
                return valid
                    ? "Related"
                    : limited ? "Recent" : "All"
            case .new:
                return "New"
            case .none:
                return nil
            }
        }
    }

    lazy var dataSource = DataSource(tableView: tableView) { tableView, indexPath, itemIdentifier in
        tableView.render(itemIdentifier, for: indexPath) as ID.Cell
    }

    var loaded = false
    func snapshot(initial: Bool = true) {
        guard loaded || initial else { return }
        loaded = true
        var snapshot = NSDiffableDataSourceSnapshot<LinkSection, ID>()
        if ids.count > 0 {
            let section = LinkSection.notes(valid: query.valid, limited: query.limited)
            snapshot.appendSections([section])
            snapshot.appendItems(ids, toSection: section)
        }
        snapshot.appendSections([.new])
        snapshot.appendItems([ID(file: "", name: search.text ?? "")], toSection: .new)
        dataSource.apply(snapshot)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let selected = tableView.indexPathForSelectedRow else { return }
        UIView.animate(withDuration: 0.25, animations: {
            self.tableView.deselectRow(at: selected, animated: true)
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(settings))
        query = ID.search(text: "")
        let progress = UIProgressView(progressViewStyle: .bar)
        progressSink = Engine.progress.sink {
            progress.progress = $0
        }
        tableView.dataSource = dataSource
        let stack = UIStackView(arrangedSubviews: [search, progress, tableView])
            .pinned(to: view)
        stack.axis = .vertical
    }

    @objc func settings() {
        show(SettingsController(), sender: self)
    }
}

extension MenuController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        query?.text = searchText
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

extension MenuController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let split = splitViewController,
              let nav = split.viewController(for: .secondary) as? UINavigationController,
              let id = dataSource.itemIdentifier(for: indexPath) else { return }
        let edit = dataSource.sectionIdentifier(for: indexPath.section) == .new
        nav.viewControllers = [NoteController.with(id: id, edit: edit)]
        split.show(.secondary)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        tableView.render {
            switch self.dataSource.sectionIdentifier(for: section) {
            case .notes:
                self.query?.toggleLimit()
            default:
                break
            }
        } as TappableHeader
    }
}
