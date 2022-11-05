import Combine
import GRDBPlus
import MarkCell
import NotesUI
import UIKit
import UIKitPlus

class ImportController: UIViewController {
    enum Error: LocalizedError {
        case unknown
    }

    lazy var tableView = {
        let view = UITableView().pinned(to: self.view)
        view.register(FileCell.self)
        view.register(EditCell.self)
        view.backgroundColor = .clear
        view.dataSource = self
        return view
    }()

    let linkController = LinkController()

    struct Item {
        let temp: URL
        let name: String
        let ext: String

        var file: String { "\(name).\(ext)" }

        init(url: URL) throws {
            temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.copyItem(at: url, to: temp)
            name = url.deletingPathExtension().lastPathComponent
            ext = url.pathExtension.lowercased()
        }
    }

    var progress = Progress()

    var items: [Item] = []

    func loadItems() async throws {
        guard let input = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        for provider in input.flatMap({ $0.attachments ?? [] }) {
            items.append(try await load(provider: provider))
        }
        tableView.reloadData()
    }

    func load(provider: NSItemProvider) async throws -> Item {
        try await withCheckedThrowingContinuation { continuation in
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                let child = provider.loadInPlaceFileRepresentation(forTypeIdentifier: "public.image") { url, inPlace, error in
                    guard let url = url else {
                        continuation.resume(with: .failure(error ?? Error.unknown))
                        return
                    }
                    do {
                        continuation.resume(with: .success(try Item(url: url)))
                    } catch {
                        continuation.resume(with: .failure(error))
                    }
                }
                progress.addChild(child, withPendingUnitCount: 0)
                return
            }
            continuation.resume(with: .failure(Error.unknown))
        }
    }

    var errorSink: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        errorSink = Engine.shared.errors.sink {
            print($0)
        }
        tableView.backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        linkController.delegate = self
        add(linkController)
        Task {
            try! await loadItems()
        }
    }
}

extension ImportController: LinkControllerDelegate {
    func adjustInset(by offset: CGFloat) {
        tableView.contentInset.bottom = offset
        tableView.verticalScrollIndicatorInsets.bottom = offset
    }

    func subscribe<T>(_ action: @escaping (T.Value) -> Void, to query: T) -> AnyCancellable where T: GRDBPlus.Query, T.Value: Equatable {
        Engine.shared.subscribe(action, to: query)
    }
}

extension ImportController: EditCellDelegate {
    func change(text: String) {}

    func openLink(to url: URL, with text: String) -> Bool {
        return false
    }
}

extension ImportController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        2
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.row {
        case 0:
            return tableView.render(items[indexPath.section].temp, for: indexPath) as FileCell
        default:
            return tableView.render((text: "", with: self, search: linkController), for: indexPath) as EditCell
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        items[section].file
    }
}
