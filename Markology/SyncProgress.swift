import Combine
import UIKit

class SyncProgress: UIProgressView {
    var subscription: AnyCancellable?

    init() {
        super.init(frame: .zero)
        progressViewStyle = .bar
        progress = World.shared.loadingProgress.value
        subscription = World.shared.loadingProgress.sink { current in
            DispatchQueue.main.async {
                guard current > self.progress else {
                    self.progress = current
                    return
                }
                self.setProgress(current, animated: true)
            }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
