import Combine
import UIKit

class SettingsController: UIViewController {
    var busySink: AnyCancellable?
    var progressSink: AnyCancellable?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        let toggle = UISwitch()
        toggle.isOn = Engine.paths.icloud
        toggle.addTarget(self, action: #selector(icloud), for: .valueChanged)
        let label = UILabel()
        label.text = "Use iCloud"
        let enable = UIStackView(arrangedSubviews: [label, toggle])
        busySink = Engine.paths.busy.sink { busy in
            DispatchQueue.main.async {
                toggle.isEnabled = Engine.paths.icloudAvailable && !busy
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
            .pinned(to: view, bottom: false)
        stack.axis = .vertical
        stack.layoutMargins = .padded
        stack.isLayoutMarginsRelativeArrangement = true
        stack.spacing = 5
    }

    @objc func icloud(sender: UISwitch) {
        Engine.paths.icloud = sender.isOn
    }

    @objc func sync() {}

    @objc func folder() {
        open(url: Engine.paths.documents)
    }

    func open(url: URL) {
        #if targetEnvironment(macCatalyst)
            UIApplication.shared.open(url)
        #else
            guard let url = NSURLComponents(url: url, resolvingAgainstBaseURL: true) else { return }
            url.scheme = "shareddocuments"
            guard let url = url.url else { return }
            UIApplication.shared.open(url)
        #endif
    }
}
