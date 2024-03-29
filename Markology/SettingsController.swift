import Combine
import UIKit

class SettingsController: UIViewController {
    let toggle = UISwitch()
    var busySink: AnyCancellable?
    var progressSink: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        toggle.addTarget(self, action: #selector(icloud), for: .valueChanged)
        let label = UILabel()
        label.text = "Use iCloud"
        let enable = UIStackView(arrangedSubviews: [label, toggle])
        busySink = Engine.paths.busy.sink { busy in
            DispatchQueue.main.async {
                self.reset(busy: busy)
            }
        }

        let progress = UIProgressView(progressViewStyle: .bar)
        progressSink = Engine.progress.sink {
            progress.progress = $0
        }

        var views = [enable, progress]

        if FileManager.default.fileExists(atPath: Engine.paths.documents.path) {
            let cloudButton = UIButton(type: .system)
            cloudButton.setTitle("Open Folder", for: .normal)
            cloudButton.addTarget(self, action: #selector(folder), for: .touchUpInside)
            views.append(cloudButton)
        }

        let stack = UIStackView(arrangedSubviews: views)
            .pinned(to: view, bottom: .none)
        stack.axis = .vertical
        stack.isLayoutMarginsRelativeArrangement = true
        stack.spacing = 5
        reset()
    }

    func reset(busy: Bool = false) {
        toggle.isOn = Engine.paths.icloudAvailable && Engine.paths.icloud
        toggle.isEnabled = Engine.paths.icloudAvailable && !busy
    }

    @objc func icloud(sender: UISwitch) {
        Engine.paths.icloud = sender.isOn
    }

    @objc func folder() {
        Engine.paths.documents.open()
    }
}
