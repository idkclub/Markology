import GRDB
import UIKit

class RelatedController: UITableViewController {
    var entry: Note.Entry?
    var entryQuery: DatabaseCancellable?
    var fromConnections: [[Reference]] = []
    var toConnections: [[Reference]] = []
    let onSelect: (Note.Entry) -> Void

    init(to entry: Note.Entry, onSelect: @escaping ((Note.Entry) -> Void)) {
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
        reload(with: entry)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func reloadData() {
        tableView.reloadData()
        // TODO: This doesn't seem to select correctly on initial load.
        DispatchQueue.main.async {
            guard let current = self.sections.firstIndex(of: .current) else { return }
            self.tableView.selectRow(at: .init(row: 0, section: current), animated: false, scrollPosition: .middle)
        }
    }

    func connections(from: [Reference], excluding: [Reference]) -> [[Reference]] {
        var cells: [[Reference]] = []
        var query = from
        var toExclude = excluding
        // TODO: Load lazily.
        for _ in 1 ... 3 {
            toExclude.append(contentsOf: query)
            let results = World.shared.connections(of: query, excluding: toExclude)
            if results.count == 0 {
                break
            }
            cells.append(results)
            query = results
        }
        return cells
    }

    func reload(with entry: Note.Entry?) {
        defer { self.reloadData() }
        guard entry != self.entry else { return }
        toConnections = []
        self.entry = entry
        guard let entry = entry else { return }
        let current = entry.note.reference()
        if entry.from.count > 0 {
            fromConnections = connections(from: entry.from, excluding: [current])
        }
        if entry.to.count > 0 {
            toConnections = connections(from: entry.to, excluding: [current])
        }
    }

    private enum Section: Equatable {
        case from, current, to
        case fromConnections(Int), toConnections(Int)
    }

    private var sections: [Section] {
        var sections: [Section] = [.current]
        guard let entry = entry else { return sections }
        if entry.from.count > 0 {
            sections.insert(.from, at: 0)
            for i in fromConnections.indices {
                sections.insert(.fromConnections(i), at: 0)
            }
        }
        if entry.to.count > 0 {
            sections.append(.to)
            for i in toConnections.indices {
                sections.append(.toConnections(i))
            }
        }
        return sections
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(Reference.Cell.self, forCellReuseIdentifier: Reference.Cell.id)
    }

    func select(note: Reference) {
        entryQuery = World.shared.load(note: note, onChange: reload)
    }

    override func tableView(_: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let entry = entry else { return nil }
        let ref: Reference
        switch sections[indexPath.section] {
        case let .fromConnections(n):
            ref = fromConnections[n][indexPath.row]
        case .from:
            ref = entry.from[indexPath.row]
        case .current:
            onSelect(entry)
            dismiss(animated: true)
            return nil
        case .to:
            ref = entry.to[indexPath.row]
        case let .toConnections(n):
            ref = toConnections[n][indexPath.row]
        }
        select(note: ref)
        return indexPath
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .from:
            return "Linked From"
        case .current:
            return "Selected"
        case .to:
            return "Linked To"
        case let .toConnections(n), let .fromConnections(n):
            return "\(n + 1) Degree\(n > 0 ? "s" : "") Out"
        }
    }

    override func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let entry = entry else { return 0 }
        switch sections[section] {
        case let .fromConnections(n):
            return fromConnections[n].count
        case .from:
            return entry.from.count
        case .current:
            return 1
        case .to:
            return entry.to.count
        case let .toConnections(n):
            return toConnections[n].count
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let entry = entry else { return UITableViewCell() }
        let ref: Reference
        switch sections[indexPath.section] {
        case let .fromConnections(n):
            ref = fromConnections[n][indexPath.row]
        case .from:
            ref = entry.from[indexPath.row]
        case .current:
            ref = entry.note.reference()
        case .to:
            ref = entry.to[indexPath.row]
        case let .toConnections(n):
            ref = toConnections[n][indexPath.row]
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: Reference.Cell.id, for: indexPath) as! Reference.Cell
        cell.render(name: ref.name)
        return cell
    }
}
