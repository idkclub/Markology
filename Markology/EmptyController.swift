import UIKit

class EmptyController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Welcome"
        let text = UITextView().pinned(to: view)
        text.text = "Select or create a new note on the sidebar to get started."
        text.isSelectable = false
        text.font = UIFont.preferredFont(forTextStyle: .body)
        text.textColor = .secondaryLabel
    }
}
