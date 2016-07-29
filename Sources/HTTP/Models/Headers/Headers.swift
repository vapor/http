// TODO: => Core

public protocol KeyAccessible {
    associatedtype Key
    associatedtype Value
    subscript(key: Key) -> Value? { get set }
}

extension Dictionary: KeyAccessible {}

extension KeyAccessible where Key == HeaderKey, Value == String {
    subscript(str: String) -> Value? {
        get {
            return self[HeaderKey(str)]
        }
        set {
            self[HeaderKey(str)] = newValue
        }
    }
}

// TODO: => Core ^

public struct HeaderKey: Hashable, CustomStringConvertible {
    public let key: String
    public init(_ key: String) {
        self.key = key.capitalized
    }
}

extension HeaderKey {
    public var description: String {
        return key
    }
}

extension HeaderKey: Equatable {}

extension HeaderKey {
    public var hashValue: Int {
        return key.hashValue
    }
}

public func ==(lhs: HeaderKey, rhs: HeaderKey) -> Bool {
    return lhs.key == rhs.key
}

extension HeaderKey: ExpressibleByStringLiteral {
    public init(stringLiteral string: String) {
        self.init(string)
    }

    public init(extendedGraphemeClusterLiteral string: String){
        self.init(string)
    }

    public init(unicodeScalarLiteral string: String){
        self.init(string)
    }
}
