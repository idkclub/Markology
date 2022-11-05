import Combine
import MarkCell
import Markdown
import MarkView
import Notes
import Paths
import UIKit
import UIKitPlus

class NoteController: UIViewController, Bindable {
    static func with(id: ID, edit: Bool = false) -> NoteController {
        let note = NoteController()
        note.edit = edit
        note.id = id
        return note
    }

    private enum Section: Equatable {
        case file
        case note, edit
        case from(Int), to(Int)

        var count: Int {
            switch self {
            case .file, .note, .edit:
                return 1
            case let .from(count), let .to(count):
                return count
            }
        }
    }

    private(set) var document: NoteDocument?
    private var entrySink: AnyCancellable?
    private var entry: Entry? {
        didSet { reload() }
    }

    lazy var tableView: UITableView = {
        let tableView = UITableView().pinned(toKeyboardAnd: view, top: false)
        tableView.register(FileCell.self)
        tableView.register(EditCell.self)
        tableView.register(EmptyCell.self)
        tableView.register(MarkCell.self)
        tableView.register(Entry.Link.Cell.self)
        tableView.delegate = self
        tableView.dataSource = self
        return tableView
    }()

    private var linkSink: AnyCancellable?
    private var linkQuery: ID.Search? {
        didSet {
            guard let linkQuery = linkQuery else {
                linkSink = nil
                return
            }
            linkSink = Engine.subscribe(with(\.link), to: linkQuery)
        }
    }

    private var showLinks: Bool = false {
        didSet {
            collectionView.isHidden = !showLinks
            let offset = showLinks ? 50.0 : 0
            tableView.contentInset.bottom = offset
            tableView.verticalScrollIndicatorInsets.bottom = offset
        }
    }

    private var link: [ID] = [] {
        didSet {
            showLinks = true
            collectionView.reloadData()
            collectionView.setContentOffset(.zero, animated: false)
        }
    }

    var search: String? {
        didSet {
            guard search != oldValue else { return }
            guard let search = search else {
                showLinks = false
                linkQuery = nil
                return
            }
            linkQuery = ID.search(text: search, limit: 5)
        }
    }

    lazy var collectionView: UICollectionView = {
        let size = 40.0
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.estimatedItemSize = CGSize(width: size, height: size)
        layout.headerReferenceSize = CGSize(width: size, height: size)
        layout.sectionFootersPinToVisibleBounds = true
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout).pinned(toKeyboardAnd: view, top: false)
        collectionView.register(LinkCell.self)
        collectionView.register(header: Header.self)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.heightAnchor.constraint(equalToConstant: size).isActive = true
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

    var id: ID? {
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
            entrySink = Engine.subscribe(with(\.entry), to: Entry.load(id: id))
        }
    }

    var text: String {
        document?.text ?? entry?.text ?? ""
    }

    var addLink = PassthroughSubject<(url: String, text: String), Never>()

    func navigate(to id: ID) {
        guard let nav = navigationController else { return }
        nav.show(NoteController.with(id: id, edit: edit), sender: self)
    }

    @objc func menu() {
        guard let id = id else { return }
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if !text.isEmpty {
            menu.addAction(UIAlertAction(title: "Share Note", style: .default) { _ in
                let activityVc = UIActivityViewController(activityItems: [self.text], applicationActivities: nil)
                activityVc.popoverPresentationController?.barButtonItem = self.menuButton
                self.present(activityVc, animated: true)
            })
        }
        if !id.file.isMarkdown {
            menu.addAction(UIAlertAction(title: "Open File", style: .default) { _ in
                id.file.url.open()
            })
        }
        menu.addAction(UIAlertAction(title: "Delete \(id.file.isMarkdown ? "Note" : "File")", style: .destructive) { [weak self] _ in
            let confirm = UIAlertController(title: "Delete \(self?.entry?.name ?? id.name)?", message: "This operation cannot be undone.", preferredStyle: .alert)
            confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            confirm.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
                Task {
                    if let document = self?.document {
                        _ = await document.close()
                    }
                    self?.document = nil
                    let file = Engine.paths.locate(file: id.file)
                    DispatchQueue.main.async {
                        var error: NSError?
                        NSFileCoordinator().coordinate(writingItemAt: file.url, options: .forDeleting, error: &error) {
                            do {
                                try FileManager.default.removeItem(at: $0)
                            } catch {
                                Engine.errors.send(error)
                            }
                        }
                        if let error = error {
                            Engine.errors.send(error)
                        }
                        if !file.name.isMarkdown {
                            NSFileCoordinator().coordinate(writingItemAt: file.name.markdown.url, options: .forDeleting, error: &error) {
                                do {
                                    try FileManager.default.removeItem(at: $0)
                                } catch {
                                    Engine.errors.send(error)
                                }
                            }
                            if let error = error {
                                Engine.errors.send(error)
                            }
                        }
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

    var loaded = false
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        collectionView.backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        loaded = true
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

    private func reload() {
        title = entry?.name ?? id?.name
        guard edit, document == nil else {
            layout()
            return
        }
        Task {
            await openDocument()
            layout()
        }
    }

    private func openDocument() async {
        guard let id = id, document == nil else { return }
        let document = NoteDocument(name: id.file.markdown)
        if FileManager.default.fileExists(atPath: document.fileURL.path) {
            guard await document.open() else {
                edit = false
                return
            }
        } else {
            do {
                try FileManager.default.createDirectory(at: document.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            } catch {
                Engine.errors.send(error)
            }
            document.text = id.name.isEmpty ? "" : "# \(id.name)\n\n"
            guard await document.save(to: document.fileURL, for: .forCreating) else {
                edit = false
                return
            }
        }
        self.document = document
    }

    private func layout() {
        var sections: [Section] = []
        if id?.file.isMarkdown == false {
            sections.append(.file)
        }
        sections.append(edit ? .edit : .note)
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
        reloadTable(with: sections)
    }

    private var sections: [Section] = []
    private func reloadTable(with sections: [Section]) {
        guard loaded else {
            self.sections = sections
            return
        }
        let last = self.sections
        tableView.performBatchUpdates {
            self.sections = sections
            if last.count > sections.count {
                self.tableView.deleteSections(IndexSet(integersIn: sections.count ..< last.count), with: .fade)
            } else if sections.count > last.count {
                self.tableView.insertSections(IndexSet(integersIn: last.count ..< sections.count), with: .fade)
            }
            for (index, section) in sections.enumerated() {
                if index >= last.count {
                    self.tableView.insertRows(at: (0 ..< section.count).map { IndexPath(row: $0, section: index) }, with: .automatic)
                    continue
                }
                if section.count > last[index].count {
                    self.tableView.insertRows(at: (last[index].count ..< section.count).map { IndexPath(row: $0, section: index) }, with: .fade)
                } else if section.count < last[index].count {
                    self.tableView.deleteRows(at: (section.count ..< last[index].count).map { IndexPath(row: $0, section: index) }, with: .fade)
                }
                if section != last[index] {
                    let index = (0 ..< min(section.count, last[index].count)).map { IndexPath(row: $0, section: index) }
                    self.tableView.reloadRows(at: index, with: .automatic)
                } else if section != .edit {
                    self.tableView.reloadRows(at: (0 ..< min(section.count, last[index].count)).map { IndexPath(row: $0, section: index) }, with: .automatic)
                }
            }
        }
    }
}

extension NoteController: MarkCellDelegate, EditCellDelegate {
    func change(text: String) {
        guard let document = document else { return }
        document.text = text
        document.updateChangeCount(.done)
    }

    func openLink(to url: URL, with text: String) -> Bool {
        guard url.host == nil else { return true }
        guard let relative = id?.file.use(for: url.path) else { return false }
        navigate(to: ID(file: relative, name: text))
        return false
    }

    func resolve(path: String) -> String? {
        guard let relative = id?.file.use(forEncoded: path) else { return nil }
        return relative.url.path.removingPercentEncoding
    }
}

extension NoteController: SearchDelegate {
    func change(search: String) {
        self.search = search
    }
}

extension NoteController: CheckboxDelegate {
    func checkboxToggled(at line: Int) {
        Task {
            await openDocument()
            guard let document = document else { return }
            var lines = document.text.components(separatedBy: .newlines)
            let current = lines[line - 1]
            guard let bracket = current.firstIndex(of: "[") else { return }
            let index = current.index(after: bracket)
            lines[line - 1] = current.replacingCharacters(in: index ... index, with: current[index] == " " ? "x" : " ")
            document.text = lines.joined(separator: "\n")
            document.updateChangeCount(.done)
            UIView.performWithoutAnimation {
                reload()
            }
        }
    }
}

extension NoteController: KeyCommandable {
    func handle(_ command: UIKeyCommand) {
        toggleEdit()
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
        case .file:
            return String(entry.file.dropFirst())
        case .edit, .note:
            return "Last Updated \(date.string(from: entry.modified))"
        case .from:
            return "Linked From"
        case .to:
            return "Linked To"
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch sections[indexPath.section] {
        case .file:
            return tableView.render(id!.file.url, for: indexPath) as FileCell
        case .note:
            if entry == nil || (!id!.file.isMarkdown && entry?.text == ""), document == nil {
                return tableView.render(id!.file, for: indexPath) as EmptyCell
            }
            return tableView.render((text: text, with: self), for: indexPath) as MarkCell
        case .edit:
            return tableView.render((text: text, with: self), for: indexPath) as EditCell
        case .from:
            return tableView.render((link: entry!.from[indexPath.row], note: entry!.name), for: indexPath) as Entry.Link.Cell
        case .to:
            return tableView.render((link: entry!.to[indexPath.row], note: entry!.name), for: indexPath) as Entry.Link.Cell
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch sections[section] {
        case .file, .note, .edit:
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
        let dest: ID
        switch sections[indexPath.section] {
        case .note:
            edit = true
            reload()
            return
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
            return collectionView.render(linkQuery.valid ? "clock" : "magnifyingglass", forHeader: indexPath) as Header
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
        let target: ID
        switch linkSections[indexPath.section] {
        case .notes:
            target = link[indexPath.row]
        case .new:
            guard let search = search else { return }
            target = .generate(for: search)
        }
        guard let url = target.file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }
        addLink.send((url: url, text: target.name))
    }
}

extension NoteController {
    class LinkCell: UICollectionViewCell, RenderCell {
        lazy var label: UILabel = {
            UILabel().pinned(to: contentView, layout: true)
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
        func render(_ file: File.Name) {
            var content = defaultContentConfiguration()
            content.text = file.isMarkdown ?
                "\n\n\(file.dropFirst()) wasn't found. Begin editing to create it.\n\n" :
                "No note currently attached. Begin editing to create one."
            content.textProperties.color = .placeholderText
            content.textProperties.alignment = .center
            contentConfiguration = content
        }
    }
}
