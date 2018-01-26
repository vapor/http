import Foundation
import Bits

/// Representation of the HTTP headers associated with a `HTTPRequest` or `HTTPResponse`.
/// Headers are subscriptable using case-insensitive comparison or provide `Name` constants. eg.
///
/// ```swift
///    let contentLength = headers["Content-Length"]
/// ```
/// or
/// ```swift
///    let contentLength = headers[.contentLength]
/// ```
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/headers/)
public struct HTTPHeaders: Codable {
    /// The HTTPHeader's raw data storage
    /// Note: For COW to work properly, this must only be
    /// accessed from the public methods on this struct.
    internal var storage: HTTPHeaderStorage

    /// Creates a new, empty `HTTPHeaders`.
    public init() {
        self.storage = .init()
    }

    /// Create a new `HTTPHeaders` with explicit storage and indexes.
    internal init(storage: HTTPHeaderStorage) {
        self.storage = storage
    }

    /// See `Encodable.encode(to:)`
    public func encode(to encoder: Encoder) throws {
        try Array(self).encode(to: encoder)
    }

    /// See `Decodable.init(from:)`
    public init(from decoder: Decoder) throws {
        let headers = try [HTTPHeaderName: String](from: decoder)
        
        self.init()
        
        for (name, value) in headers {
            self[name] = value
        }
    }
    
    /// Accesses all values associated with the `Name`
    public subscript(valuesFor name: HTTPHeaderName) -> [String] {
        get {
            return storage.indexes(for: name).flatMap { storage.value(for: $0) }
        }
        set {
            if !isKnownUniquelyReferenced(&storage) {
                /// this storage is being referenced from two places
                /// copy now to ensure COW behavior
                storage = storage.copy()
            }
            storage.removeValues(for: name)
            for value in newValue {
                storage.appendValue(value, for: name)
            }
        }
    }
}

/// MARK: Convenience

extension HTTPHeaders {
    /// Accesses the (first) value associated with the `Name` if any
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/http/headers/#accessing-headers)
    public subscript(name: HTTPHeaderName) -> String? {
        get {
            switch name {
            case HTTPHeaderName.setCookie: // Exception, see note in [RFC7230, section 3.2.2]
                return self[valuesFor: .setCookie].first
            default:
                let values = self[valuesFor: name]
                if values.isEmpty {
                    return nil
                }
                return values.joined(separator: ",")
            }
        }
        set {
            if let value = newValue {
                self[valuesFor: name] = [value]
            } else {
                self[valuesFor: name] = []
            }
        }
    }


    /// https://tools.ietf.org/html/rfc2616#section-3.6
    ///
    /// "Parameters are in  the form of attribute/value pairs."
    ///
    /// From a header + attribute, this subscript will fetch a value
    public subscript(name: HTTPHeaderName, attribute: String) -> String? {
        get {
            guard let header = self[name] else { return nil }
            guard let range = header.range(of: "\(attribute)=") else { return nil }

            let remainder = header[range.upperBound...]

            var string: String

            if let end = remainder.index(of: ";") {
                string = String(remainder[remainder.startIndex..<end])
            } else {
                string = String(remainder[remainder.startIndex...])
            }

            if string.first == "\"", string.last == "\"", string.count > 1 {
                string.removeFirst()
                string.removeLast()
            }

            return string
        }
    }
}



/// MARK: Utility

extension HTTPHeaders: CustomStringConvertible {
    /// See `CustomStringConvertible.description`
    public var description: String {
        return storage.description
    }
}

/// Joins two headers, overwriting the data in `lhs` with `rhs`' equivalent for duplicated
public func +(lhs: HTTPHeaders, rhs: HTTPHeaders) -> HTTPHeaders {
    var lhs = lhs
    
    for (key, value) in rhs {
        lhs[key] = value
    }
    
    return lhs
}


/// MARK: Literal Conformances

extension HTTPHeaders : ExpressibleByDictionaryLiteral {
    /// Creates HTTP headers.
    public init(dictionaryLiteral: (HTTPHeaderName, String)...) {
        self.init()
        
        for (name, value) in dictionaryLiteral {
            storage.appendValue(value, for: name)
        }
    }
}

extension HTTPHeaders {
    /// Used instead of HTTPHeaders to save CPU on dictionary construction
    public struct Literal : ExpressibleByDictionaryLiteral {
        let fields: [(name: HTTPHeaderName, value: String)]
        
        public init(dictionaryLiteral: (HTTPHeaderName, String)...) {
            fields = dictionaryLiteral
        }
    }
    
    /// Appends a header to the headers
    public mutating func append(_ literal: HTTPHeaders.Literal) {
        for (name, value) in literal.fields {
            storage.appendValue(value, for: name)
        }
    }
    
    /// Replaces a header in the headers
    public mutating func replace(_ literal: HTTPHeaders.Literal) {
        for (name, value) in literal.fields {
            self[valuesFor: name] = [value]
        }
    }
}

/// MARK: Sequence Conformance

extension HTTPHeaders: Sequence {
    /// Iterates over all headers
    public func makeIterator() -> AnyIterator<(name: HTTPHeaderName, value: String)> {
        let storage = self.storage
        var indexIterator = storage.validIndexes().makeIterator()
        return AnyIterator {
            guard let header = indexIterator.next() else {
                return nil
            }
            
            let name = storage.name(for: header) ?? ""
            let value = storage.value(for: header) ?? ""
            return (HTTPHeaderName(data: Array(name.utf8)), value)
        }
    }
}
