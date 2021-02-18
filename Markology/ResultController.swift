import GRDB
import UIKit

class ResultController: UITableViewController {
    var resultsQuery: DatabaseCancellable?
    var notes: [Note] = []

    init(query: String) {
        super.init(style: .insetGrouped)
        title = "Results for \"\(query)\""
        resultsQuery = World.shared.search(query: query) { [weak self] (notes: [Note]) in
            self?.notes = notes
            self?.tableView.reloadData()
        }
        tableView.register(Reference.Cell.self, forCellReuseIdentifier: Reference.Cell.id)
        tableView.register(Note.Cell.self, forCellReuseIdentifier: Note.Cell.id)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func numberOfSections(in _: UITableView) -> Int {
        notes.count
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        notes[section].binary ? 1 : 2
    }

    override func tableView(_: UITableView, didSelectRowAt indexPath: IndexPath) {
        navigate(to: notes[indexPath.section].reference())
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: Reference.Cell.id, for: indexPath) as! Reference.Cell
            cell.render(name: notes[indexPath.section].name)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: Note.Cell.id, for: indexPath) as! Note.Cell
        cell.render(note: notes[indexPath.section], navigate: navigate)
        return cell
    }
}
