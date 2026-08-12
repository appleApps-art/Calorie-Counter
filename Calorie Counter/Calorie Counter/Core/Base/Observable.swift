import Foundation

final class Observable<Value> {
    var value: Value {
        didSet {
            listeners.forEach { $0(value) }
        }
    }

    private var listeners: [(Value) -> Void] = []

    init(_ value: Value) {
        self.value = value
    }

    func bind(_ listener: @escaping (Value) -> Void) {
        listeners.append(listener)
        listener(value)
    }
}
