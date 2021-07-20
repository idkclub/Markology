import GRDB
import UIKit

class SearchResultController: UITableViewController {
    var resultsQuery: DatabaseCancellable?
    var notes: [Note] = []
    var query: String

    init(query: String) {
        self.query = query
        super.init(style: .insetGrouped)
        title = "Results for \"\(query)\""
        resultsQuery = World.shared.search(query: query) { [weak self] (notes: [Note]) in
            self?.notes = notes
            self?.tableView.reloadData()
        }
        tableView.register(ReferenceCell.self, forCellReuseIdentifier: ReferenceCell.id)
        tableView.register(NoteCell.self, forCellReuseIdentifier: NoteCell.id)
        tableView.register(ImageCell.self, forCellReuseIdentifier: ImageCell.id)
        clearsSelectionOnViewWillAppear = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func numberOfSections(in _: UITableView) -> Int {
        notes.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard !notes[section].binary else { return notes[section].image != nil ? 2 : 1 }
        return 2
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        navigate(to: notes[indexPath.section].reference())
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard indexPath.row > 0 else {
            let cell = tableView.dequeueReusableCell(withIdentifier: ReferenceCell.id, for: indexPath) as! ReferenceCell
            cell.render(name: notes[indexPath.section].name)
            return cell
        }
        guard !notes[indexPath.section].binary else {
            let cell = tableView.dequeueReusableCell(withIdentifier: ImageCell.id, for: indexPath) as! ImageCell
            cell.render(image: notes[indexPath.section].image)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: NoteCell.id, for: indexPath) as! NoteCell
        cell.render(note: notes[indexPath.section], delegate: self)
        cell.highlight(search: query)
        return cell
    }
}
