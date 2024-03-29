import Combine
import GRDBPlus
import MarkCell
import Markdown
import MarkView
import Notes
import NotesUI
import Paths
import QuickLook
import UIKit
import UIKitPlus

class NoteController: UIViewController, Bindable {
    static func with(id: ID, edit: Bool = false) -> NoteController {
        let note = NoteController()
        note.edit = edit
        note.id = id
        return note
    }

    private(set) var document: NoteDocument?
    private var entrySink: AnyCancellable?
    private var entry: Entry? {
        didSet {
            if oldValue?.from != entry?.from || oldValue?.to != entry?.to {
                connections = []
                radar()
            }
            reload()
        }
    }

    enum Section: Hashable {
        case file(String)
        case note
        case from, to
        case connection(Int)
    }

    enum Item: Hashable {
        case file(URL)
        case note(String)
        case edit
        case empty(String)
        // The same link can appear in both.
        case from(Entry.Link), to(Entry.Link)
        case connection(ID.Connection)
    }

    class DataSource: FadingTableSource<Section, Item> {
        weak var controller: NoteController?
        init(controller: NoteController, tableView: UITableView, cellProvider: @escaping UITableViewDiffableDataSource<NoteController.Section, NoteController.Item>.CellProvider) {
            self.controller = controller
            super.init(tableView: tableView, cellProvider: cellProvider)
        }

        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            switch sectionIdentifier(for: section) {
            case let .file(file):
                return file
            case .note:
                return nil
            case .from:
                return "Linked From"
            case .to:
                return "Linked To"
            case let .connection(level):
                return "\(level + 2) Degrees Out"
            default:
                return nil
            }
        }
    }

    private lazy var dataSource = DataSource(controller: self, tableView: tableView) { tableView, indexPath, itemIdentifier in
        switch itemIdentifier {
        case let .file(url):
            return tableView.render((url: url, parent: self), for: indexPath) as FileCell
        case let .note(text):
            return tableView.render((text: text, with: self), for: indexPath) as MarkCell
        case .edit:
            return tableView.render((text: self.text, with: self, search: self.linkController), for: indexPath) as EditCell
        case let .empty(file):
            return tableView.render(file, for: indexPath) as EmptyCell
        case let .from(link), let .to(link):
            return tableView.render((link: link, note: self.entry?.name ?? ""), for: indexPath) as Entry.Link.Cell
        case let .connection(connection):
            return tableView.render(connection, for: indexPath) as ID.Connection.Cell
        }
    }

    var keyboardSink: AnyCancellable?
    lazy var keyboard = {
        let keyboard = KeyboardGuide.within(view: view)
        keyboardSink = keyboard.offset.sink { self.keyboardOffset = $0 }
        return keyboard
    }()

    var keyboardOffset = 0.0 {
        didSet { offset() }
    }

    var linkOffset = 0.0 {
        didSet { offset() }
    }

    func offset() {
        let offset = keyboardOffset + linkOffset
        tableView.contentInset.bottom = offset
        tableView.verticalScrollIndicatorInsets.bottom = offset
    }

    lazy var tableView: UITableView = {
        let tableView = UITableView().pinned(to: view, anchor: .view)
        tableView.register(header: DateHeader.self)
        tableView.register(header: TappableHeader.self)
        tableView.register(FileCell.self)
        tableView.register(EditCell.self)
        tableView.register(EmptyCell.self)
        tableView.register(MarkCell.self)
        tableView.register(Entry.Link.Cell.self)
        tableView.register(ID.Connection.Cell.self)
        return tableView
    }()

    let linkController = LinkController()

    private lazy var menuButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: self, action: #selector(menu))

    var edit = false
    @objc func toggleEdit() {
        if edit {
            linkController.search = nil
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
            guard id == nil else { return }
            guard let split = splitViewController,
                  let nav = navigationController else { return }
            if nav.viewControllers.count > 1 {
                nav.popViewController(animated: true)
            } else {
                nav.viewControllers = [EmptyController()]
                split.show(.primary)
            }
        }
    }

    var offscreen: Bool = true
    var animating: Bool = false
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard let id = id else { return }
        offscreen = false
        animating = false
        entrySink = Engine.shared.subscribe(with(\.entry), to: Entry.load(id: id))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        offscreen = true
        entrySink?.cancel()
        sync()
    }

    var text: String {
        document?.text ?? entry?.text ?? ""
    }

    var radarLoading = false
    var connections: [[ID.Connection]] = []
    func radar() {
        guard !radarLoading, let entry = entry else { return }
        if let last = connections.last, last.isEmpty { return }
        radarLoading = true
        DispatchQueue.global(qos: .utility).async {
            defer { self.radarLoading = false }
            var source: [ID]
            var exclude: [ID]
            if self.connections.isEmpty {
                source = [entry.from, entry.to].joined().map { $0.note }
                exclude = [entry.id]
            } else {
                source = self.connections.last?.map { $0.id } ?? []
                exclude = [entry.id] + [entry.from, entry.to].joined().map { $0.note } + self.connections.joined().map { $0.id }
            }
            guard !source.isEmpty else { return }
            do {
                let connections = try Engine.shared.db.read {
                    try ID.connections(db: $0, of: source, excluding: exclude)
                }
                self.connections.append(connections)
                DispatchQueue.main.async {
                    self.reload()
                }
            } catch {
                self.alert(error: error)
            }
        }
    }

    func navigate(to id: ID) {
        guard let nav = navigationController else { return }
        nav.show(NoteController.with(id: id, edit: edit), sender: self)
    }

    @objc func menu() {
        guard let id = id else { return }
        let menu = UIAlertController()
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
                    guard let self = self else { fatalError("lost self") }
                    if let document = self.document {
                        await document.close()
                    }
                    self.document = nil
                    self.id = nil
                    let file = Engine.paths.locate(file: id.file)
                    Task.detached {
                        defer { Engine.shared.delete(files: [file]) }
                        do {
                            try FileManager.default.removeItem(at: file.url)
                        } catch {
                            Engine.errors.send(error)
                        }
                        guard !file.name.isMarkdown else { return }
                        let note = file.name.markdown.url
                        guard FileManager.default.fileExists(atPath: note.path) else { return }
                        do {
                            try FileManager.default.removeItem(at: note)
                        } catch {
                            Engine.errors.send(error)
                        }
                    }
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
        tableView.dataSource = dataSource
        tableView.delegate = self
        linkController.delegate = self
        add(linkController)
        linkController.view.pinned(to: view, anchor: .view, bottom: .against(keyboard), top: .none)
        reload()
        radar()
    }

    private func sync() {
        if let id = id,
           let document = document,
           document.hasUnsavedChanges
        {
            Task {
                do {
                    try await document.savePresentedItemChanges()
                } catch {
                    alert(error: error)
                }
                Task.detached {
                    Engine.shared.update(files: [Engine.paths.locate(file: id.file)])
                }
            }
        }
    }

    private var header: DateHeader?
    private func reload() {
        guard let id = id, !offscreen else { return }
        title = entry?.name ?? id.name
        header?.render(entry?.modified)
        guard edit, document == nil else {
            snapshot()
            return
        }
        Task {
            await openDocument()
            snapshot()
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

    private func snapshot() {
        var items: [UIBarButtonItem] = []
        if entry != nil || document != nil {
            items.append(menuButton)
        }
        let toggle = UIBarButtonItem(image: edit ? UIImage(systemName: "checkmark") : UIImage(systemName: "pencil"), style: .plain, target: self, action: #selector(toggleEdit))
        toggle.title = "Toggle Editing"
        items.append(toggle)
        navigationItem.rightBarButtonItems = items
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        defer {
            dataSource.apply(snapshot, animatingDifferences: animating)
            animating = true
        }
        guard let id = id else { return }
        if !id.file.isMarkdown {
            let section = Section.file(String(id.file.dropFirst()))
            snapshot.appendSections([section])
            snapshot.appendItems([.file(id.file.url)], toSection: section)
        }
        guard let entry = entry else {
            snapshot.appendSections([.note])
            snapshot.appendItems([edit ? .edit : .empty(id.file)], toSection: .note)
            return
        }
        snapshot.appendSections([.note])
        if !id.file.isMarkdown, entry.text == "", document == nil {
            snapshot.appendItems([.empty(id.file)], toSection: .note)
        } else {
            snapshot.appendItems([edit ? .edit : .note(text)], toSection: .note)
        }
        if entry.from.count > 0 {
            snapshot.appendSections([.from])
            snapshot.appendItems(entry.from.map { .from($0) }, toSection: .from)
        }
        if entry.to.count > 0 {
            snapshot.appendSections([.to])
            snapshot.appendItems(entry.to.map { .to($0) }, toSection: .to)
        }
        for (index, connection) in connections.enumerated() {
            guard !connection.isEmpty else { break }
            let section = Section.connection(index)
            snapshot.appendSections([section])
            snapshot.appendItems(connection.map { .connection($0) }, toSection: section)
        }
    }
}

extension NoteController: UIDropInteractionDelegate {
    func dropInteraction(_: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        session.hasItemsConforming(toTypeIdentifiers: ["public.image"])
    }

    func dropInteraction(_: UIDropInteraction, sessionDidUpdate _: UIDropSession) -> UIDropProposal {
        UIDropProposal(operation: .copy)
    }

    func dropInteraction(_: UIDropInteraction, performDrop session: UIDropSession) {
        let controller = AttachController()
        controller.delegate = controller
        controller.insert = linkController
        present(controller, animated: true)
        controller.load(providers: session.items.map { $0.itemProvider })
    }
}

class AttachController: ImportController, ImportControllerDelegate {
    var insert: SearchDelegate?
    func dismiss(importing: [(url: String, text: String)]) {
        for url in importing {
            insert?.receiver?.add(link: url, replace: false)
        }
    }

    public func url(file: String) -> URL {
        file.url
    }

    public func subscribe<T>(_ action: @escaping (T.Value) -> Void, to query: T) -> AnyCancellable where T: GRDBPlus.Query, T.Value: Equatable {
        Engine.shared.subscribe(action, to: query)
    }
}

extension NoteController: LinkControllerDelegate {
    func subscribe<T>(_ action: @escaping (T.Value) -> Void, to query: T) -> AnyCancellable where T: GRDBPlus.Query, T.Value: Equatable {
        Engine.shared.subscribe(action, to: query)
    }

    func adjustInset(by offset: CGFloat) {
        linkOffset = offset
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
            animating = false
            reload()
        }
    }
}

extension NoteController: KeyCommandable {
    func handle(_ command: UIKeyCommand) {
        toggleEdit()
    }
}

extension NoteController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let dest: ID
        switch dataSource.itemIdentifier(for: indexPath) {
        case .file:
            open()
            return
        case .note, .empty:
            edit = true
            reload()
            return
        case let .from(link), let .to(link):
            dest = link.note
        case let .connection(connection):
            dest = connection.id
        default:
            return
        }
        navigate(to: dest)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        switch dataSource.sectionIdentifier(for: section) {
        case .note:
            let header = tableView.render(header: entry?.modified) as DateHeader
            self.header = header
            return header
        // TODO: See if this is cached across connection resets.
        case let .connection(level):
            if level == connections.count - 1 {
                radar()
            }
        default:
            break
        }
        return tableView.render {
            guard case .file = self.dataSource.sectionIdentifier(for: section) else { return }
            self.open()
        } as TappableHeader
    }
}

extension NoteController: QLPreviewControllerDataSource {
    func open() {
        let controller = QLPreviewController()
        controller.dataSource = self
        #if targetEnvironment(macCatalyst)
            splitViewController?.show(controller, sender: self)
        #else
            navigationController?.show(controller, sender: self)
        #endif
    }

    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
    }

    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        self
    }
}

extension NoteController: QLPreviewItem {
    var previewItemURL: URL? {
        id?.file.url
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

extension NoteController {
    class DateHeader: UITableViewHeaderFooterView, RenderCell {
        private var date: DateFormatter {
            let date = DateFormatter()
            date.dateStyle = .short
            date.timeStyle = .short
            return date
        }

        func render(_ date: Date?) {
            guard let date = date else {
                render(text: "New Note")
                return
            }
            render(text: "Last Updated \(self.date.string(from: date))")
        }

        func render(text: String) {
            var content = defaultContentConfiguration()
            content.text = text
            contentConfiguration = content
        }
    }
}
