/**
    We can't generically extend optionals based on their contents being protocols concretely,
    ie: where Wrapped == SomeProtocol

    This allows us to do so because extending protocol can use concrete generic constraints
*/
public protocol Extractable {

    /**
        The underlying type
    */
    associatedtype Wrapped

    /**
        Access the underlying value

        - returns: the underlying value if exists
    */
    func extract() -> Wrapped?
}

extension Extractable where Wrapped == String {
    public var isNilOrEmpty: Bool {
        guard let val = extract() else { return true }
        return val.isEmpty
    }
}

extension Optional: Extractable {
    public func extract() -> Wrapped? {
        guard case let .some(value) = self else { return nil }
        return value
    }
}
