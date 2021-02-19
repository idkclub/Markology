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
        tableView.register(Note.Image.self, forCellReuseIdentifier: Note.Image.id)
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
            let cell = tableView.dequeueReusableCell(withIdentifier: Reference.Cell.id, for: indexPath) as! Reference.Cell
            cell.render(name: notes[indexPath.section].name)
            return cell
        }
        guard !notes[indexPath.section].binary else {
            let cell = tableView.dequeueReusableCell(withIdentifier: Note.Image.id, for: indexPath) as! Note.Image
            cell.render(image: notes[indexPath.section].image)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: Note.Cell.id, for: indexPath) as! Note.Cell
        cell.render(note: notes[indexPath.section], navigate: navigate)
        return cell
    }
}
