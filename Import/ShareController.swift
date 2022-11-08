import Combine
import GRDBPlus
import MarkCell
import NotesUI
import UIKit
import UIKitPlus

class ShareController: ImportController {
    var errors: AnyCancellable?
    override func viewDidLoad() {
        super.viewDidLoad()
        errors = Engine.shared.errors.sink(receiveValue: alert)
        guard let items = (extensionContext?.inputItems as? [NSExtensionItem]) else { return }
        load(providers: items.flatMap { $0.attachments ?? [] })
    }

    override func cancel() {
        super.cancel()
        extensionContext?.completeRequest(returningItems: nil)
    }
}

extension ShareController: LinkControllerDelegate {
    func subscribe<T>(_ action: @escaping (T.Value) -> Void, to query: T) -> AnyCancellable where T: GRDBPlus.Query, T.Value: Equatable {
        Engine.shared.subscribe(action, to: query)
    }
}
