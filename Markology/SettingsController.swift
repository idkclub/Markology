import UIKit
import Utils

class SettingsController: UITableViewController {
    private enum Section: Int {
        case cloud, progress, sync
    }

    private let sections: [Section] = [.cloud, .progress, .sync]
    private let toggle = UISwitch()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.allowsSelection = false
        title = "Settings"
    }

    override func numberOfSections(in _: UITableView) -> Int {
        1
    }

    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        sections.count
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell()
        switch sections[indexPath.row] {
        case .cloud:
            toggle.isOn = Container.icloud
            toggle.isEnabled = Container.icloudEnabled
            toggle.addTarget(self, action: #selector(icloud), for: .valueChanged)
            cell.textLabel?.text = toggle.isEnabled ? "Use iCloud Sync" : "Sign in to iCloud to Sync"
            cell.accessoryView = toggle
        case .progress:
            SyncProgress().anchored(to: cell.contentView, horizontal: true, top: true, bottom: true)
        case .sync:
            let button = UIButton(type: .system).anchored(to: cell.contentView, horizontal: true, top: true, bottom: true)
            button.setTitle("Force Sync", for: .normal)
            button.addTarget(self, action: #selector(sync), for: .touchUpInside)
        }
        return cell
    }

    @objc private func icloud() {
        do {
            try World.shared.syncSync(force: true)
            try Container.setCloud(enabled: toggle.isOn)
        } catch {
            navigationController?.splitViewController?.errorAlert(for: error)
        }
        toggle.isOn = Container.icloud
        World.shared.sync()
    }

    @objc private func sync() {
        World.shared.sync(force: true)
    }
}
