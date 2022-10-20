import Combine
import Markdown
import UIKit

class NoteController: UIViewController, Bindable {
    static func with(id: Note.ID, edit: Bool = false) -> NoteController {
        let note = NoteController()
        note.edit = edit
        note.id = id
        return note
    }

    private enum Section: Equatable {
        case note, edit
        case from(Int), to(Int)

        var count: Int {
            switch self {
            case .note, .edit:
                return 1
            case let .from(count), let .to(count):
                return count
            }
        }
    }

    private(set) var document: NoteDocument?
    private var sections: [Section] = []
    private var entrySink: AnyCancellable?
    private var entry: Note.Entry? {
        didSet { reload() }
    }

    lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.register(EditCell.self)
        tableView.register(EmptyCell.self)
        tableView.register(NoteCell<Self>.self)
        tableView.register(Note.Entry.Link.Cell.self)
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()

    private var linkSink: AnyCancellable?
    private var link: [Note.ID] = [] {
        didSet {
            // TODO: Animate?
            collectionView.isHidden = false
            collectionView.reloadData()
        }
    }

    var search: String? {
        didSet {
            guard search != oldValue else { return }
            guard let search = search else {
                collectionView.isHidden = true
                linkSink = nil
                return
            }
            linkSink = Engine.subscribe(with(\.link), to: Note.ID.Search(text: search))
        }
    }

    lazy var collectionView: UICollectionView = {
        let size = 40.0
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.estimatedItemSize = CGSize(width: size, height: size)
        layout.headerReferenceSize = CGSize(width: size, height: size)
        layout.sectionFootersPinToVisibleBounds = true
        let collectionView = UICollectionView(frame: .infinite, collectionViewLayout: layout)
        collectionView.register(LinkCell.self)
        collectionView.register(header: Header.self)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.heightAnchor.constraint(equalToConstant: size).isActive = true
        collectionView.backgroundColor = .secondarySystemBackground
        collectionView.isHidden = true
        return collectionView
    }()

    private lazy var menuButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: self, action: #selector(menu))

    var edit = false
    @objc func toggleEdit() {
        if edit {
            search = nil
            sync()
        }
        edit = !edit
        reload()
    }

    var id: Note.ID? {
        didSet {
            if id != oldValue {
                document = nil
            }
            guard let id = id else {
                guard let split = splitViewController,
                      let nav = navigationController else { return }
                if nav.viewControllers.count > 1 {
                    nav.popViewController(animated: true)
                } else {
                    nav.viewControllers = [EmptyController()]
                    split.show(.primary)
                }
                return
            }
            entrySink = Engine.subscribe(with(\.entry), to: Note.Entry.Load(id: id))
        }
    }

    var text: String {
        document?.text ?? entry?.text ?? ""
    }

    var addLink = PassthroughSubject<Note.ID, Never>()

    @objc func menu() {
        guard let id = id else { return }
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if !text.isEmpty {
            menu.addAction(UIAlertAction(title: "Share", style: .default) { _ in
                let activityVc = UIActivityViewController(activityItems: [self.text], applicationActivities: nil)
                activityVc.popoverPresentationController?.barButtonItem = self.menuButton
                self.present(activityVc, animated: true)
            })
        }
        menu.addAction(UIAlertAction(title: "Delete Note", style: .destructive) { [weak self] _ in
            let confirm = UIAlertController(title: "Delete \(self?.entry?.name ?? id.name)?", message: "This operation cannot be undone.", preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            confirm.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                Task {
                    if let document = self?.document {
                        _ = await document.close()
                    }
                    self?.document = nil
                    let file = Engine.paths.locate(file: id.file)
                    // TODO: Handle errors.
                    var error: NSError?
                    NSFileCoordinator().coordinate(writingItemAt: file.url, options: .forDeleting, error: &error) {
                        try? FileManager.default.removeItem(at: $0)
                    }
                    Engine.shared.delete(files: [file])
                    self?.id = nil
                }
            })
            self?.present(confirm, animated: true)
        })
        menu.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        menu.modalPresentationStyle = .popover
        menu.popoverPresentationController?.barButtonItem = menuButton
        present(menu, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let stack = UIStackView(arrangedSubviews: [tableView, collectionView]).pinned(to: view, bottom: false)
        stack.axis = .vertical
        stack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor).isActive = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        sync()
    }

    private func sync() {
        if let id = id,
           let document = document,
           document.hasUnsavedChanges
        {
            Engine.shared.update(file: id.file, with: text)
        }
    }

    private func reload(sections: [Section]) {
        let last = self.sections
        self.sections = sections
        tableView.performBatchUpdates {
            if last.count > sections.count {
                self.tableView.deleteSections(IndexSet(integersIn: sections.count ..< last.count), with: .automatic)
            } else if sections.count > last.count {
                self.tableView.insertSections(IndexSet(integersIn: last.count ..< sections.count), with: .fade)
            }
            for (index, section) in sections.enumerated() {
                if index >= last.count {
                    self.tableView.insertRows(at: (0 ..< section.count).map { IndexPath(row: $0, section: index) }, with: .middle)
                    continue
                }
                if section.count > last[index].count {
                    self.tableView.insertRows(at: (last[index].count ..< section.count).map { IndexPath(row: $0, section: index) }, with: .automatic)
                } else if section.count < last[index].count {
                    self.tableView.deleteRows(at: (section.count ..< last[index].count).map { IndexPath(row: $0, section: index) }, with: .automatic)
                }
                if section != last[index] {
                    self.tableView.reloadRows(at: (0 ..< min(section.count, last[index].count)).map { IndexPath(row: $0, section: index) }, with: .fade)
                } else if section != .edit {
                    self.tableView.reloadRows(at: (0 ..< min(section.count, last[index].count)).map { IndexPath(row: $0, section: index) }, with: .none)
                }
            }
        }
    }

    private func reload() {
        title = entry?.name ?? id?.name
        guard let id = id else { return }
        Task {
            if edit, document == nil {
                let document = NoteDocument(name: id.file)
                // TODO: Handle errors.
                if FileManager.default.fileExists(atPath: document.fileURL.path) {
                    guard await document.open() else { return }
                } else {
                    try? FileManager.default.createDirectory(at: document.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    document.text = id.name.isEmpty ? "" : "# \(id.name)\n\n"
                    guard await document.save(to: document.fileURL, for: .forCreating) else { return }
                }
                self.document = document
            }
            var sections: [Section] = [edit ? .edit : .note]
            if let count = entry?.from.count, count > 0 {
                sections.append(.from(count))
            }
            if let count = entry?.to.count, count > 0 {
                sections.append(.to(count))
            }
            var items: [UIBarButtonItem] = []
            if entry != nil || document != nil {
                items.append(menuButton)
            }
            items.append(UIBarButtonItem(image: edit ? UIImage(systemName: "checkmark") : UIImage(systemName: "pencil"), style: .plain, target: self, action: #selector(toggleEdit)))
            navigationItem.rightBarButtonItems = items
            reload(sections: sections)
        }
    }
}

extension NoteController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    private var date: DateFormatter {
        let date = DateFormatter()
        date.dateStyle = .short
        date.timeStyle = .short
        return date
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let entry = entry else { return nil }
        switch sections[section] {
        case .edit, .note:
            return "Last Updated \(date.string(from: entry.note.modified))"
        case .from:
            return "Linked From"
        case .to:
            return "Linked To"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .note:
            if entry == nil, document == nil {
                return tableView.render(id!.file, for: indexPath) as EmptyCell
            }
            return tableView.render(NoteCell.Value(file: id!.file, text: text), with: self, for: indexPath) as NoteCell
        case .edit:
            return tableView.render(NoteCell.Value(file: id!.file, text: text), with: self, for: indexPath) as EditCell
        case .from:
            return tableView.render(entry!.from[indexPath.row], with: entry!.name, for: indexPath) as Note.Entry.Link.Cell
        case .to:
            return tableView.render(entry!.to[indexPath.row], with: entry!.name, for: indexPath) as Note.Entry.Link.Cell
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .note, .edit:
            return 1
        case .from:
            return entry?.from.count ?? 0
        case .to:
            return entry?.to.count ?? 0
        }
    }
}

extension NoteController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let dest: Note.ID
        switch sections[indexPath.section] {
        case .from:
            dest = entry!.from[indexPath.row].note
        case .to:
            dest = entry!.to[indexPath.row].note
        default:
            return
        }
        navigate(to: dest)
    }
}

extension NoteController: UICollectionViewDataSource {
    var linkSections: [MenuController.Section] {
        var sections: [MenuController.Section] = []
        if link.count > 0 {
            sections.append(.notes)
        }
        sections.append(.new)
        return sections
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        linkSections.count
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch linkSections[indexPath.section] {
        case .notes:
            return collectionView.render("magnifyingglass", forHeader: indexPath) as Header
        case .new:
            return collectionView.render("plus", forHeader: indexPath) as Header
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch linkSections[section] {
        case .notes:
            return link.count
        case .new:
            return 1
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch linkSections[indexPath.section] {
        case .notes:
            return collectionView.render(link[indexPath.row].name, for: indexPath) as LinkCell
        case .new:
            return collectionView.render(search ?? "", for: indexPath) as LinkCell
        }
    }
}

extension NoteController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let target: Note.ID
        switch linkSections[indexPath.section] {
        case .notes:
            target = link[indexPath.row]
        case .new:
            guard let search = search else { return }
            target = .generate(for: search)
        }
        addLink.send(target)
    }
}

extension NoteController {
    class LinkCell: UICollectionViewCell, RenderCell {
        lazy var label: UILabel = {
            UILabel().pinned(to: contentView)
        }()

        func render(_ text: String) {
            if text == "" {
                label.text = "Empty Note"
                label.textColor = .placeholderText
            } else {
                label.text = text
                label.textColor = .label
            }
        }
    }
}

extension NoteController {
    class Header: UICollectionReusableView, RenderCell {
        lazy var image: UIImageView = {
            UIImageView().pinned(to: self, withInset: 10)
        }()

        func render(_ symbol: String) {
            image.image = UIImage(systemName: symbol)
            image.tintColor = .secondaryLabel
        }
    }
}

extension NoteController {
    class EmptyCell: UITableViewCell, RenderCell {
        func render(_ file: Paths.File.Name) {
            var content = defaultContentConfiguration()
            content.text = "\n\n\(file.dropFirst()) wasn't found. Begin editing to create it.\n\n"
            content.textProperties.color = .placeholderText
            content.textProperties.alignment = .center
            contentConfiguration = content
        }
    }
}

extension NoteController: Navigator {
    func navigate(to id: Note.ID) {
        guard let nav = navigationController else { return }
        nav.show(NoteController.with(id: id, edit: edit), sender: self)
    }
}
