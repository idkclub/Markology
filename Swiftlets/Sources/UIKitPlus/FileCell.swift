import QuickLook
import UIKit

public class FileCell: UITableViewCell, RenderCell {
    var height: NSLayoutConstraint?
    var url: URL?
    var timer: Timer? {
        didSet {
            oldValue?.invalidate()
        }
    }

    lazy var progress = UIActivityIndicatorView().pinned(to: contentView, top: .none)

    lazy var quicklook = {
        let controller = QLPreviewController()
        controller.dataSource = self
        controller.view.pinned(to: contentView, anchor: .view)
        let height = contentView.heightAnchor.constraint(equalToConstant: 300)
        height.priority = .defaultHigh
        height.isActive = true
        return controller
    }()

    public func render(_ value: (url: URL, parent: UIViewController)) {
        timer = nil
        url = value.url
        if quicklook.parent != value.parent {
            value.parent.add(quicklook)
        }
        let attrs = try? value.url.resourceValues(forKeys: [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey])
        if attrs?.isUbiquitousItem == true, attrs?.ubiquitousItemDownloadingStatus != .current {
            progress.startAnimating()
            try? FileManager.default.startDownloadingUbiquitousItem(at: value.url)
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if (try? value.url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]).ubiquitousItemDownloadingStatus) == .current {
                    self.timer = nil
                    self.progress.stopAnimating()
                    self.quicklook.reloadData()
                }
            }
        }
        quicklook.reloadData()
    }
}

extension FileCell: QLPreviewControllerDataSource {
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        timer != nil ? 0 : 1
    }

    public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        self
    }
}

extension FileCell: QLPreviewItem {
    public var previewItemURL: URL? {
        url
    }
}
