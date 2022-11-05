import MarkView
import UIKit
import UIKitPlus

class ImportController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let view = MarkView().pinned(to: view)
        view.render(text: "# Test", includingMarkup: true)
    }
}
