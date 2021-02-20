import UIKit

public class ErrorAlert: UIAlertController {
    public init(error: Error) {
        super.init(nibName: nil, bundle: nil)
        title = "An Error Occured!"
        message = error.localizedDescription
        addAction(.init(title: "┬─┬ノ( º _ ºノ)", style: .cancel) { _ in self.dismiss(animated: true) })
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
