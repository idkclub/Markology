import UIKit
import Utils

@objc(ImportViewController) class ImportViewController: FileController {
    override func viewDidLoad() {
        guard let input = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        with(providers: input.flatMap { $0.attachments ?? [] }) { _ in
            self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
        super.viewDidLoad()
    }
}
