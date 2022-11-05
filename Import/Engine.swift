import Combine
import Foundation
import GRDB
import GRDBPlus
import Notes
import Paths

class Engine: DataSource {
    static let shared = try! Engine()
    let errors = PassthroughSubject<Error, Never>()
    let paths = Paths(for: (Bundle.main.bundleIdentifier! as NSString).deletingPathExtension)
    let db: DatabaseWriter
    init() throws {
        let cache = paths.cached(file: "note.db")!
        var config = Configuration()
        config.foreignKeysEnabled = false
        db = try DatabasePool(path: cache.path, configuration: config)
        try Note.migrate(db: db)
    }
}
