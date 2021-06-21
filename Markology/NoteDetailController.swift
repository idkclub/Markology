import GRDB
import UIKit
import Utils

class NoteDetailController: UITableViewController {
    let note: Reference
    var entryQuery: DatabaseCancellable?
    var entry: Note.Entry?
    var relatedButton: UIBarButtonItem?
    var menuButton: UIBarButtonItem?
    var expandFrom = false
    var expandTo = false
    var relatedController: UIViewController?

    var noteContent: Any? { return entry?.note.image ?? entry?.note.text }

    init(note: Reference) {
        self.note = note
        super.init(style: .insetGrouped)
        title = note.name
        entryQuery = World.shared.load(note: note, onChange: reload)
        relatedButton = UIBarButtonItem(image: UIImage(systemName: "dot.radiowaves.left.and.right"), style: .plain, target: self, action: #selector(related))
        menuButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: self, action: #selector(menu))
        clearsSelectionOnViewWillAppear = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private enum Section: Int {
        case from, to, note, image
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
        if entry.note.binary {
            if self.entry?.note.image != nil {
                sections.append(.image)
            }
        } else {
            sections.append(.note)
        }
        return sections
    }

    func reload(with entry: Note.Entry?) {
        defer { tableView.reloadData() }
        self.entry = entry
        guard let entry = entry, let menuButton = menuButton, let relatedButton = relatedButton else {
            title = ""
            navigationItem.setRightBarButtonItems([], animated: true)
            return
        }
        title = entry.note.name
        var buttons: [UIBarButtonItem] = [menuButton]
        if entry.to.count > 0 || entry.from.count > 0 {
            buttons.append(relatedButton)
        }
        if !entry.note.binary {
            buttons.append(.init(image: UIImage(systemName: "pencil"), style: .plain, target: self, action: #selector(edit)))
        }
        navigationItem.setRightBarButtonItems(buttons, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(TappableHeader.self, forHeaderFooterViewReuseIdentifier: TappableHeader.id)
        tableView.register(ReferenceCell.self, forCellReuseIdentifier: ReferenceCell.id)
        tableView.register(NoteCell.self, forCellReuseIdentifier: NoteCell.id)
        tableView.register(ImageCell.self, forCellReuseIdentifier: ImageCell.id)
    }

    override func viewDidAppear(_: Bool) {
        if let related = relatedController {
            // Seems to prevent a crash if backgrounded with the related controller open.
            related.popoverPresentationController?.sourceView = view
        }
    }

    @objc private func related() {
        guard let current = entry?.note.reference() else { return }
        let related = RelatedController.withTitle(to: current) { [weak self] related, ref in
            let controller = NoteDetailController(note: ref)
            controller.relatedController = related
            self?.show(controller, sender: self)
            related.popoverPresentationController?.barButtonItem = controller.relatedButton
        }
        related.modalPresentationStyle = .popover
        related.popoverPresentationController?.barButtonItem = relatedButton
        present(related, animated: true)
    }

    @objc private func menu() {
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if noteContent != nil {
            menu.addAction(UIAlertAction(title: "Share", style: .default) { [weak self] _ in self?.share() })
        }
        menu.addAction(UIAlertAction(title: "Delete Note", style: .destructive) { [weak self] _ in
            guard let note = self?.note else { return }
            let confirm = UIAlertController(title: "Delete \(note.name)?", message: "This operation cannot be undone.", preferredStyle: .alert)
            confirm.addAction(.init(title: "Cancel", style: .cancel))
            confirm.addAction(.init(title: "🔥", style: .destructive) { [weak self] _ in
                do {
                    try World.shared.delete(url: Container.url(for: note.file))
                } catch { self?.errorAlert(for: error) }
                self?.navigationController?.pop()
            })
            self?.present(confirm, animated: true)
        })
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        menu.modalPresentationStyle = .popover
        menu.popoverPresentationController?.barButtonItem = menuButton
        present(menu, animated: true)
    }

    @objc private func edit() {
        guard let entry = entry else { return }
        present(EditController(path: entry.note.file, text: entry.note.text), animated: true)
    }

    private func share() {
        guard let content = noteContent else { return }
        let activityVc = UIActivityViewController(activityItems: [content], applicationActivities: nil)
        activityVc.popoverPresentationController?.barButtonItem = menuButton
        present(activityVc, animated: true)
    }

    var date: DateFormatter {
        let date = DateFormatter()
        date.dateStyle = .short
        date.timeStyle = .short
        return date
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TappableHeader.id) as? TappableHeader else { return nil }
        switch sections[section] {
        case .note, .image:
            break
        case .from:
            header.onTap = { [weak self] in
                guard let self = self else { return }
                self.expandFrom = !self.expandFrom
                tableView.reloadData()
            }
        case .to:
            header.onTap = { [weak self] in
                guard let self = self else { return }
                self.expandTo = !self.expandTo
                tableView.reloadData()
            }
        }
        return header
    }

    override func tableView(_: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let entry = entry else { return nil }
        let ref: Reference
        switch sections[indexPath.section] {
        case .to:
            ref = entry.to[indexPath.row]
        case .from:
            ref = entry.from[indexPath.row]
        case .note, .image:
            return nil
        }
        navigate(to: ref)
        return indexPath
    }

    override func tableView(_: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let entry = entry else { return nil }
        switch sections[section] {
        case .from:
            return "Linked From\(entry.from.count > 5 && !expandFrom ? " (\(entry.from.count - 5) hidden)" : "")"
        case .to:
            return "Linked To\(entry.to.count > 5 && !expandTo ? " (\(entry.to.count - 5) hidden)" : "")"
        case .note, .image:
            return "Last Modified \(date.string(from: entry.note.modified))"
        }
    }

    override func numberOfSections(in _: UITableView) -> Int {
        sections.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let entry = entry else { return 0 }
        switch sections[section] {
        case .from:
            return expandFrom ? entry.from.count : min(entry.from.count, 5)
        case .to:
            return expandTo ? entry.to.count : min(entry.to.count, 5)
        case .note, .image:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let entry = entry else { return UITableViewCell() }
        let ref: Reference
        switch sections[indexPath.section] {
        case .to:
            ref = entry.to[indexPath.row]
        case .from:
            ref = entry.from[indexPath.row]
        case .note:
            let cell = tableView.dequeueReusableCell(withIdentifier: NoteCell.id, for: indexPath) as! NoteCell
            cell.render(note: entry.note, delegate: self)
            return cell
        case .image:
            let cell = tableView.dequeueReusableCell(withIdentifier: ImageCell.id, for: indexPath) as! ImageCell
            cell.render(image: self.entry?.note.image)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: ReferenceCell.id, for: indexPath) as! ReferenceCell
        cell.render(name: ref.name)
        return cell
    }
}
