import Combine
import GRDB
import UIKit
import Utils

class MenuController: UIViewController {
    let table: UITableView
    let showCancel: Bool
    let showCreateEmpty: Bool
    let delegate: MenuDelegate
    var query: String = ""
    var notes: [Reference] = []
    var notesQuery: DatabaseCancellable?
    var includeAll = false

    init(style: UITableView.Style = .insetGrouped, initial: String = "", showCancel: Bool = false, showCreateEmpty: Bool = true, delegate: MenuDelegate) {
        self.showCancel = showCancel
        self.showCreateEmpty = showCreateEmpty
        self.delegate = delegate
        query = initial
        table = UITableView(frame: .zero, style: style)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private enum Section: Int, CaseIterable {
        case recent, new
    }

    private var sections: [Section] {
        var sections: [Section] = []
        if notes.count > 0 {
            sections.append(.recent)
        }
        if showCreateEmpty || query != "" {
            sections.append(.new)
        }
        return sections
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationController?.navigationBar.prefersLargeTitles = true
        title = "Markology"
        view.backgroundColor = .systemGroupedBackground
        navigationItem.setRightBarButton(.init(image: UIImage(systemName: "gear"), style: .plain, target: self, action: #selector(settings)), animated: true)
        let progress = SyncProgress().anchored(to: view, horizontal: true, top: true)

        let searchBar = UISearchBar().anchored(to: view, horizontal: true)
        searchBar.text = query
        searchBar.placeholder = "Search"
        searchBar.delegate = self
        searchBar.enablesReturnKeyAutomatically = false
        #if !targetEnvironment(macCatalyst)
            searchBar.showsCancelButton = showCancel
        #endif

        table.anchored(to: view, horizontal: true, bottom: true)
        table.keyboardDismissMode = .onDrag
        table.dataSource = self
        table.delegate = self
        table.register(TappableHeader.self, forHeaderFooterViewReuseIdentifier: TappableHeader.id)
        table.register(ReferenceCell.self, forCellReuseIdentifier: ReferenceCell.id)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: progress.bottomAnchor),
            table.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
        ])
        reloadQuery()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let selected = table.indexPathForSelectedRow else { return }
        // Jank version of clearsSelectionOnViewWillAppear.
        UIView.animate(withDuration: 0.25, animations: {
            self.table.deselectRow(at: selected, animated: true)
        })
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        view.endEditing(true)
    }

    func reloadQuery() {
        notesQuery = World.shared.search(query: query, recent: !includeAll) { [weak self] (notes: [Reference]) in
            guard let self = self else { return }
            self.notes = notes
            self.table.reloadData()
        }
    }

    @objc private func settings() {
        show(SettingsController(style: .insetGrouped), sender: self)
    }

    @objc private func sync() {
        World.shared.sync(force: true)
    }
}

extension MenuController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange _: String) {
        query = searchBar.text ?? ""
        reloadQuery()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        delegate.search(query: searchBar.text ?? "")
    }

    // https://stackoverflow.com/questions/58468235/uisearchcontroller-uisearchbar-behaves-differently-under-macos-than-ios
    #if !targetEnvironment(macCatalyst)
        func searchBarCancelButtonClicked(_: UISearchBar) {
            dismiss(animated: true)
        }
    #endif
}

extension MenuController: UITableViewDelegate {
    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .recent:
            return includeAll ? "All" : "Most Recent"
        case .new:
            return "New"
        }
    }

    func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch sections[indexPath.section] {
        case .recent:
            delegate.select(note: notes[indexPath.row])
        case .new:
            delegate.create(query: query)
        }
    }
}

extension MenuController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .recent:
            return notes.count
        case .new:
            return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReferenceCell.id, for: indexPath) as! ReferenceCell
        switch sections[indexPath.section] {
        case .recent:
            cell.render(name: notes[indexPath.row].name)
        case .new:
            cell.render(name: query)
        }
        return cell
    }

    func tableView(_: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = table.dequeueReusableHeaderFooterView(withIdentifier: TappableHeader.id) as? TappableHeader else { return nil }
        switch sections[section] {
        case .recent:
            header.onTap = { [weak self] in
                guard let self = self else { return }
                self.includeAll = !self.includeAll
                self.reloadQuery()
            }
        case .new:
            break
        }
        return header
    }
}

protocol MenuDelegate {
    func select(note: Reference)
    func create(query: String)
    func search(query: String)
}

extension MenuDelegate {
    func search(query _: String) {}
}
