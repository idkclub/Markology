import UIKitPlus
import MarkView
import UIKit

class ImportController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let view = MarkView().pinned(to: view)
        view.render(text: "# Test", includingMarkup: true)
    }
}
