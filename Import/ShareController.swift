import Combine
import GRDBPlus
import MarkCell
import Notes
import NotesUI
import UIKit
import UIKitPlus

class ShareController: ImportController {
    var errors: AnyCancellable?
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
        errors = Engine.shared.errors.sink(receiveValue: alert)
        guard let items = (extensionContext?.inputItems as? [NSExtensionItem]) else { return }
        load(providers: items.flatMap { $0.attachments ?? [] })
    }
}

extension ShareController: ImportControllerDelegate {
    func dismiss(importing: [(url: String, text: String)]) {
        extensionContext?.completeRequest(returningItems: nil)
    }

    func exists(file: String) -> Bool {
        guard let exists = (try? Engine.shared.db.read {
            return try ID.exists(db: $0, file: "/\(file)")
        }) else { return false }
        return exists
    }

    func url(file: String) -> URL {
        Engine.shared.paths.locate(file: file).url
    }

    func subscribe<T>(_ action: @escaping (T.Value) -> Void, to query: T) -> AnyCancellable where T: GRDBPlus.Query, T.Value: Equatable {
        Engine.shared.subscribe(action, to: query)
    }
}
