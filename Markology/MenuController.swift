import Combine
import GRDB
import UIKit

class MenuController: UIViewController {
    let results: UITableView
    let emptyCreate: Bool
    let delegate: MenuDelegate
    var query: String = ""
    var notes: [Reference] = []
    var notesQuery: DatabaseCancellable?
    var progressSubscription: AnyCancellable?

    init(style: UITableView.Style = .insetGrouped, emptyCreate: Bool = true, delegate: MenuDelegate) {
        self.delegate = delegate
        self.emptyCreate = emptyCreate
        results = UITableView(frame: .zero, style: style)
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
        if emptyCreate || query != "" {
            sections.append(.new)
        }
        return sections
    }

    override func viewDidLoad() {
        navigationController?.navigationBar.prefersLargeTitles = true
        title = "Markology"
        view.backgroundColor = .systemGroupedBackground
        let progress = UIProgressView().anchored(to: view, horizontal: true, top: true)
        progress.progressViewStyle = .bar
        progress.isUserInteractionEnabled = true
        progress.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(sync)))
        progressSubscription = World.shared.loadingProgress.sink { current in
            DispatchQueue.main.async {
                guard current > progress.progress else {
                    progress.progress = current
                    return
                }
                progress.setProgress(current, animated: true)
            }
        }
        let searchBar = UISearchBar().anchored(to: view, horizontal: true)
        searchBar.placeholder = "Search"
        searchBar.delegate = self
        results.anchored(to: view, horizontal: true, bottom: true)
        results.dataSource = self
        results.delegate = self
        results.register(Reference.Cell.self, forCellReuseIdentifier: Reference.Cell.id)
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: progress.bottomAnchor),
            results.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
        ])
        reloadQuery()
    }

    func reloadQuery() {
        notesQuery = World.shared.search(query: query) { [weak self] (notes: [Reference]) in
            guard let self = self else { return }
            self.notes = notes
            self.results.reloadData()
        }
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
}

extension MenuController: UITableViewDelegate {
    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .recent:
            return "Most Recent"
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
        let cell = tableView.dequeueReusableCell(withIdentifier: Reference.Cell.id, for: indexPath) as! Reference.Cell
        switch sections[indexPath.section] {
        case .recent:
            cell.render(name: notes[indexPath.row].name)
        case .new:
            cell.render(name: query)
        }
        return cell
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
