import Combine
import GRDBPlus
import MarkCell
import Notes
import UIKit
import UIKitPlus

public enum LinkSection: Hashable {
    case notes(valid: Bool, limited: Bool), new
}

public class LinkController: UIViewController, Bindable {
    let size = 40.0
    private var linkSink: AnyCancellable?
    private var linkQuery: ID.Search? {
        didSet {
            guard let linkQuery = linkQuery else {
                linkSink = nil
                return
            }
            linkSink = delegate?.subscribe(with(\.link), to: linkQuery)
        }
    }

    private var showLinks: Bool = false {
        didSet {
            collectionView.isHidden = !showLinks
            delegate?.adjustInset(by: showLinks ? size : 0)
        }
    }

    private var link: [ID] = [] {
        didSet {
            showLinks = true
            collectionView.reloadData()
            collectionView.setContentOffset(.zero, animated: false)
        }
    }

    public var delegate: LinkControllerDelegate?

    public var addLink = PassthroughSubject<(url: String, text: String), Never>()

    public var search: String? {
        didSet {
            guard search != oldValue else { return }
            guard let search = search else {
                showLinks = false
                linkQuery = nil
                return
            }
            linkQuery = ID.search(text: search, limit: 5)
        }
    }

    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.estimatedItemSize = CGSize(width: size, height: size)
        layout.headerReferenceSize = CGSize(width: size, height: size)
        layout.sectionFootersPinToVisibleBounds = true
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.register(LinkCell.self)
        collectionView.register(header: Header.self)
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.heightAnchor.constraint(equalToConstant: size).isActive = true
        collectionView.isHidden = true
        collectionView.backgroundView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        return collectionView
    }()

    override public func loadView() {
        view = collectionView
    }
}

extension LinkController: SearchDelegate {
    public func change(search: String) {
        self.search = search
    }
}

extension LinkController: UICollectionViewDataSource {
    var linkSections: [LinkSection] {
        var sections: [LinkSection] = []
        if link.count > 0 {
            sections.append(.notes(valid: linkQuery.valid, limited: linkQuery.limited))
        }
        sections.append(.new)
        return sections
    }

    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        linkSections.count
    }

    public func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        switch linkSections[indexPath.section] {
        case .notes:
            return collectionView.render(linkQuery.valid ? "magnifyingglass" : "clock", forHeader: indexPath) as Header
        case .new:
            return collectionView.render("plus", forHeader: indexPath) as Header
        }
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch linkSections[section] {
        case .notes:
            return link.count
        case .new:
            return 1
        }
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch linkSections[indexPath.section] {
        case .notes:
            return collectionView.render(link[indexPath.row].name, for: indexPath) as LinkCell
        case .new:
            return collectionView.render(search ?? "", for: indexPath) as LinkCell
        }
    }
}

extension LinkController: UICollectionViewDelegate {
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let target: ID
        switch linkSections[indexPath.section] {
        case .notes:
            target = link[indexPath.row]
        case .new:
            guard let search = search else { return }
            target = .generate(for: search)
        }
        guard let url = target.file.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return }
        addLink.send((url: url, text: target.name))
    }
}

extension LinkController {
    class LinkCell: UICollectionViewCell, RenderCell {
        lazy var label: UILabel = {
            UILabel().pinned(to: contentView, layout: true)
        }()

        func render(_ text: String) {
            if text == "" {
                label.text = "Empty Note"
                label.textColor = .placeholderText
            } else {
                label.text = text
                label.textColor = .label
            }
        }
    }
}

extension LinkController {
    class Header: UICollectionReusableView, RenderCell {
        lazy var image: UIImageView = {
            UIImageView().pinned(to: self, withInset: 10)
        }()

        func render(_ symbol: String) {
            image.image = UIImage(systemName: symbol)
            image.tintColor = .secondaryLabel
        }
    }
}

public protocol LinkControllerDelegate: Subscribable {
    func adjustInset(by offset: CGFloat)
}
