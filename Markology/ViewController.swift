import GRDB
import UIKit

class ViewController: UIViewController {
    let body = UITableView(frame: .zero, style: .insetGrouped)
    let note: Reference
    var entryQuery: DatabaseCancellable?
    var entry: Note.Entry?
    var menuButton: UIBarButtonItem?

    init(note: Reference) {
        self.note = note
        super.init(nibName: nil, bundle: nil)
        title = note.name
        entryQuery = World.shared.load(note: note, onChange: reload)
        menuButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: self, action: #selector(menu))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private enum Section: Int, CaseIterable {
        case from, to, note
    }

    private var sections: [Section] {
        guard let entry = entry else { return [] }
        var sections: [Section] = []
        if entry.from.count > 0 {
            sections.append(.from)
        }
        if entry.to.count > 0 {
            sections.append(.to)
        }
        // TODO: Handle binaries.
        if !entry.note.binary {
            sections.append(.note)
        }
        return sections
    }

    func reload(entry: Note.Entry?) {
        defer { body.reloadData() }
        self.entry = entry
        guard let entry = entry, let menuButton = menuButton else {
            title = ""
            return
        }
        title = entry.note.name
        var buttons: [UIBarButtonItem] = [menuButton]
        if !entry.note.binary {
            buttons.append(.init(image: UIImage(systemName: "pencil"), style: .plain, target: self, action: #selector(edit)))
        }
        navigationItem.setRightBarButtonItems(buttons, animated: true)
    }

    override func viewDidLoad() {
        body.anchored(to: view, horizontal: true, bottom: true)
        body.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        body.dataSource = self
        body.delegate = self
        body.register(Reference.Cell.self, forCellReuseIdentifier: Reference.Cell.id)
        body.register(Note.Cell.self, forCellReuseIdentifier: Note.Cell.id)
    }

    @objc private func menu() {
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        menu.addAction(UIAlertAction(title: "Delete Note", style: .destructive) { [weak self] _ in
            guard let note = self?.note else { return }
            let confirm = UIAlertController(title: "Delete \(note.name)?", message: "This operation cannot be undone.", preferredStyle: .alert)
            confirm.addAction(.init(title: "Cancel", style: .cancel))
            confirm.addAction(.init(title: "🔥", style: .destructive) { [weak self] _ in
                World.shared.delete(url: World.shared.url(for: note.file))
                self?.navigationController?.popViewController(animated: true)
            })
            self?.present(confirm, animated: true)
        })
        menu.modalPresentationStyle = .popover
        menu.popoverPresentationController?.barButtonItem = menuButton
        present(menu, animated: true)
    }

    @objc private func edit() {
        guard let entry = entry else { return }
        present(EditController(path: entry.note.file, text: entry.note.text), animated: true)
    }
}

extension ViewController: UITableViewDelegate {
    var date: DateFormatter {
        let date = DateFormatter()
        date.dateStyle = .short
        date.timeStyle = .short
        return date
    }

    func tableView(_: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let entry = entry else { return nil }
        let ref: Reference
        switch sections[indexPath.section] {
        case .to:
            ref = entry.to[indexPath.row]
        case .from:
            ref = entry.from[indexPath.row]
        case .note:
            return nil
        }
        navigate(to: ref)
        return indexPath
    }

    func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch sections[section] {
        case .from:
            return "Linked From"
        case .to:
            return "Linked To"
        case .note:
            guard let entry = entry else { return nil }
            return "Last Modified \(date.string(from: entry.note.modified))"
        }
    }
}

extension ViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let entry = entry else { return 0 }
        switch sections[section] {
        case .from:
            return entry.from.count
        case .to:
            return entry.to.count
        case .note:
            return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let entry = entry else { return UITableViewCell() }
        let ref: Reference
        switch sections[indexPath.section] {
        case .to:
            ref = entry.to[indexPath.row]
        case .from:
            ref = entry.from[indexPath.row]
        case .note:
            let cell = tableView.dequeueReusableCell(withIdentifier: Note.Cell.id, for: indexPath) as! Note.Cell
            cell.render(note: entry.note, navigate: navigate)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: Reference.Cell.id, for: indexPath) as! Reference.Cell
        cell.render(name: ref.name)
        return cell
    }
}
