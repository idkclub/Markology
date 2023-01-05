import Combine
import GRDB

public protocol Query {
    associatedtype Value
    func fetch(db: Database) throws -> Value
}

public protocol Subscribable {
    func subscribe<T: Query>(_ action: @escaping (T.Value) -> Void, to query: T) -> AnyCancellable where T.Value: Equatable
}

public protocol DataSource {
    var errors: PassthroughSubject<Error, Never> { get }
    var db: DatabaseWriter { get }
}

public extension DataSource {
    func subscribe<T: Query>(_ action: @escaping (T.Value) -> Void, to query: T) -> AnyCancellable where T.Value: Equatable {
        ValueObservation
            .tracking(query.fetch)
            .removeDuplicates()
            .publisher(in: db, scheduling: .immediate)
            .sink(receiveCompletion: {
                if case let .failure(err) = $0 {
                    errors.send(err)
                }
            }, receiveValue: action)
    }
}
