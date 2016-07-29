// TODO: Temporary
@_exported import Core

extension Body {
    public var bytes: Bytes? {
        guard case let .data(bytes) = self else { return nil }
        return bytes
    }
}

extension Body {
    public init(_ str: String) {
        self.init(str.bytes)
    }

    public init<S: Sequence where S.Iterator.Element == Byte>(_ s: S) {
        self = .data(s.array)
    }
}

extension Body: ExpressibleByArrayLiteral {
    /// Creates an instance initialized with the given elements.
    public init(arrayLiteral elements: Byte...) {
        self.init(elements)
    }
}
