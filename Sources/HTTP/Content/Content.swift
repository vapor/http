import Foundation

public typealias MessageCodable = MessageEncodable & MessageDecodable

/// Types conforming to this protocol can be used
/// to extract content from HTTP message bodies.
public protocol MessageDecodable {
    /// Parses the body data into content.
    static func decode(from message: Message) throws -> Self
}

/// Types conforming to this protocol can be used
/// to extract content from HTTP message bodies.
public protocol MessageEncodable {
    /// Serializes the content into body data.
    func encode(to message: Message) throws
}

// MARK: Message

extension Message {
    public var mediaType: MediaType? {
        get {
            guard let contentType = headers[.contentType] else {
                return nil
            }

            return MediaType(string: contentType)
        }
        set {
            headers[.contentType] = newValue?.description
        }
    }
}

extension Message {
    public func content<M: MessageEncodable>(_ encodable: M) throws {
        try encodable.encode(to: self)
    }

    public func content<M: MessageDecodable>(_ decodable: M.Type = M.self) throws -> M {
        return try decodable.decode(from: self)
    }
}
