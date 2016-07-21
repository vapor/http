// TODO: Temporary
@_exported import Core

extension HTTPBody {
    public var bytes: Bytes? {
        guard case let .data(bytes) = self else { return nil }
        return bytes
    }
}

extension HTTPBody {
    public init(_ str: String) {
        self.init(str.bytes)
    }

    public init<S: Sequence where S.Iterator.Element == Byte>(_ s: S) {
        self = .data(s.array)
    }
}

extension HTTPBody: ExpressibleByArrayLiteral {
    /// Creates an instance initialized with the given elements.
    public init(arrayLiteral elements: Byte...) {
        self.init(elements)
    }
}
