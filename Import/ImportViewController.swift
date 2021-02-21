import UIKit
import Utils

@objc(ImportViewController) class ImportViewController: FileController {
    override func viewDidLoad() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else { return }
        var images: [UIImage] = []
        let group = DispatchGroup()
        for item in items {
            guard let attachments = item.attachments else { continue }
            for provider in attachments {
                group.enter()
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    defer { group.leave() }
                    guard let image = image as? UIImage else {
                        guard let error = error else { return }
                        self.errorAlert(for: error)
                        return
                    }
                    images.append(image)
                }
            }
        }
        group.notify(queue: .main) {
            self.with(files: images) { _ in
                self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
            }
            super.viewDidLoad()
        }
    }
}
