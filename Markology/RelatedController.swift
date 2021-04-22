import GRDB
import UIKit

class RelatedController: UITableViewController {
    let onSelect: (Reference) -> Void
    var current: Reference {
        didSet {
            connections = []
            loading = false
            title = current.name
        }
    }

    var connections: [[Reference.Entry]] = []
    var loading = false
    var showPaths = false
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

    static func withTitle(to note: Reference, onSelect: @escaping ((Reference) -> Void)) -> UIViewController {
        UINavigationController(rootViewController: RelatedController(to: note, onSelect: onSelect))
    }

    func loadMore() {
        guard !loading else { return }
        loading = true
        DispatchQueue.global(qos: .background).async {
            if self.connections.count == 0 {
                self.connections.append(World.shared.connections(of: [self.current], excluding: [self.current]))
            } else {
                var excluded = self.connections.flatMap { $0 }.map { $0.reference }
                excluded.append(self.current)
                let next = World.shared.connections(of: self.connections[self.connections.count - 1].map { $0.reference }, excluding: excluded)
                guard next.count > 0 else { return }
                self.connections.append(next)
            }
            DispatchQueue.main.async {
                self.tableView.reloadData()
                self.loading = false
            }
        }
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(TappableHeader.self, forHeaderFooterViewReuseIdentifier: TappableHeader.id)
        tableView.register(ReferenceCell.self, forCellReuseIdentifier: ReferenceCell.id)
        tableView.register(Cell.self, forCellReuseIdentifier: Cell.id)
        navigationItem.setRightBarButtonItems([
            UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(close)),
        ], animated: true)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        navigationController?.navigationBar.isHidden = presentingViewController?.traitCollection.horizontalSizeClass == .regular && traitCollection.horizontalSizeClass == .compact
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
        return "\(section + 1) Degree\(section > 0 ? "s" : "") Out \(showPaths ? "" : "(links hidden)")"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if showPaths {
            let cell = tableView.dequeueReusableCell(withIdentifier: Cell.id, for: indexPath) as! Cell
            cell.render(entry: connections[indexPath.section][indexPath.row])
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: ReferenceCell.id, for: indexPath) as! ReferenceCell
        cell.render(name: connections[indexPath.section][indexPath.row].reference.name)
        return cell
    }

    override func tableView(_: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        let ref = connections[indexPath.section][indexPath.row].reference
        onSelect(ref)
        current = ref
        loadMore()
        return nil
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection _: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TappableHeader.id) as? TappableHeader else { return nil }
        header.onTap = { [weak self] in
            guard let self = self else { return }
            self.showPaths = !self.showPaths
            tableView.reloadData()
        }
        return header
    }
}

extension RelatedController {
    class Cell: UITableViewCell {
        static let id = "related"

        let label = UILabel()
        let paths = UIStackView()

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            accessoryView = UIImageView(image: UIImage(systemName: "chevron.forward"))
            accessoryView?.tintColor = .secondaryLabel
            label.anchored(to: contentView, top: true, constant: 11)
            paths.anchored(to: contentView, bottom: true, constant: 11)
            paths.axis = .vertical
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                label.bottomAnchor.constraint(equalTo: paths.topAnchor),
                paths.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                paths.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            ])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func render(entry: Reference.Entry) {
            let empty = entry.reference.name == ""
            label.text = empty ? "Empty Note" : entry.reference.name
            label.textColor = empty ? .placeholderText : .label
            paths.arrangedSubviews.forEach { $0.removeFromSuperview() }
            for ref in entry.from {
                let path = UILabel()
                path.textColor = .secondaryLabel
                path.text = "← \(ref.name)"
                paths.addArrangedSubview(path)
            }
            for ref in entry.to {
                let path = UILabel()
                path.textColor = .secondaryLabel
                path.text = "→ \(ref.name)"
                paths.addArrangedSubview(path)
            }
        }
    }
}
