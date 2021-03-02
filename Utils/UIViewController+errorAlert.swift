import UIKit

public extension UIViewController {
    func errorAlert(for error: Error) {
        let alert = UIAlertController(title: "An Error Occurred!", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(.init(title: "┬─┬ノ( º _ ºノ)", style: .cancel) { _ in alert.dismiss(animated: true) })
        DispatchQueue.main.async {
            self.present(alert, animated: true)
        }
    }
}
