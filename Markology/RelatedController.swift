import GRDB
import UIKit

class RelatedController: UITableViewController {
    let current: Reference
    let onSelect: (Reference) -> Void
    var connections: [[Reference]] = []
    var loading = false
    init(to note: Reference, onSelect: @escaping ((Reference) -> Void)) {
        self.onSelect = onSelect
        current = note
        super.init(style: .insetGrouped)
        title = note.name
        loadMore()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadMore() {
        guard !loading else { return }
        loading = true
        DispatchQueue.global(qos: .background).async {
            if self.connections.count == 0 {
                self.connections.append(World.shared.connections(of: [self.current], excluding: [self.current]))
            } else {
                var excluded = self.connections.flatMap { $0 }
                excluded.append(self.current)
                let next = World.shared.connections(of: self.connections[self.connections.count - 1], excluding: excluded)
                guard next.count > 0 else { return }
                self.connections.append(next)
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.loading = false
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(ReferenceCell.self, forCellReuseIdentifier: ReferenceCell.id)
    }

    override func numberOfSections(in _: UITableView) -> Int {
        connections.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        return connections[section].count
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == connections.count - 1 {
            loadMore()
        }
        return "\(section + 1) Degree\(section > 0 ? "s" : "") Out"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReferenceCell.id, for: indexPath) as! ReferenceCell
        cell.render(name: connections[indexPath.section][indexPath.row].name)
        return cell
    }

    override func tableView(_: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        onSelect(connections[indexPath.section][indexPath.row])
        dismiss(animated: true)
        return nil
    }
}
