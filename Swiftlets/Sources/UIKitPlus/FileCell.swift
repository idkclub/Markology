import QuickLook
import UIKit

public class FileCell: UITableViewCell, RenderCell {
    var height: NSLayoutConstraint?
    var url: URL?

    public lazy var quicklook = {
        let controller = QLPreviewController()
        controller.dataSource = self
        controller.view.pinned(to: contentView)
        controller.view.heightAnchor.constraint(equalToConstant: 300).isActive = true
        return controller
    }()

    public func render(_ value: (url: URL, parent: UIViewController)) {
        url = value.url
        if quicklook.parent != value.parent {
            value.parent.add(quicklook)
        }
        quicklook.reloadData()
    }
}

extension FileCell: QLPreviewControllerDataSource {
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        1
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
