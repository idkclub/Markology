import UIKit

open class FadingTableSource<Section: Hashable, Item: Hashable>: UITableViewDiffableDataSource<Section, Item> {
    public override init(tableView: UITableView, cellProvider: @escaping UITableViewDiffableDataSource<Section, Item>.CellProvider) {
        super.init(tableView: tableView, cellProvider: cellProvider)
        defaultRowAnimation = .fade
    }
}
