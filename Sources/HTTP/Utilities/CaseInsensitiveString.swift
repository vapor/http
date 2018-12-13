/// A `CaseInsensitiveString` (for `Comparable`, `Equatable`, and `Hashable`).
///
///
///     "HELLO".ci == "hello".ci // true
///
public struct CaseInsensitiveString: ExpressibleByStringLiteral, Comparable, Equatable, Hashable, CustomStringConvertible {
    /// See `Equatable`.
    public static func == (lhs: CaseInsensitiveString, rhs: CaseInsensitiveString) -> Bool {
        return lhs.storage.lowercased() == rhs.storage.lowercased()
    }
    
    /// See `Comparable`.
    public static func < (lhs: CaseInsensitiveString, rhs: CaseInsensitiveString) -> Bool {
        return lhs.storage.lowercased() < rhs.storage.lowercased()
    }
    
    /// Internal `String` storage.
    private let storage: String
    
    /// See `Hashable`.
    public var hashValue: Int {
        return storage.lowercased().hashValue
    }
    
    /// See `CustomStringConvertible`.
    public var description: String {
        return storage
    }
    
    /// Creates a new `CaseInsensitiveString`.
    ///
    ///     let ciString = CaseInsensitiveString("HeLlO")
    ///
    /// - parameters:
    ///     - string: A case-sensitive `String`.
    public init(_ string: String) {
        self.storage = string
    }
    
    /// See `ExpressibleByStringLiteral`.
    public init(stringLiteral value: String) {
        self.storage = value
    }
}

extension String {
    /// Creates a `CaseInsensitiveString` from this `String`.
    ///
    ///     "HELLO".ci == "hello".ci // true
    ///
    public var ci: CaseInsensitiveString {
        return .init(self)
    }
}
