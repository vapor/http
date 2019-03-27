import NIO
import NIOHTTP1

/// An HTTP message.
/// This is the basis of `HTTPRequest` and `HTTPResponse`. It has the general structure of:
///
///     <status line> HTTP/1.1
///     Content-Length: 5
///     Foo: Bar
///
///     hello
///
/// - note: The status line contains information that differentiates requests and responses.
///         If the status line contains an HTTP method and URI it is a request.
///         If the status line contains an HTTP status code it is a response.
///
/// This protocol is useful for adding methods to both requests and responses, such as the ability to serialize
/// content to both message types.
public protocol HTTPMessage: CustomStringConvertible, CustomDebugStringConvertible {
    /// The HTTP version of this message.
    var version: HTTPVersion { get set }

    /// The HTTP headers.
    var headers: HTTPHeaders { get set }

    /// The optional HTTP body.
    var body: HTTPBody { get set }
}

extension HTTPMessage {
    /// `MediaType` specified by this message's `"Content-Type"` header.
    public var contentType: HTTPMediaType? {
        get { return headers.firstValue(name: .contentType).flatMap(HTTPMediaType.parse) }
        set {
            if let new = newValue?.serialize() {
                headers.replaceOrAdd(name: .contentType, value: new)
            } else {
                headers.remove(name: .contentType)
            }
        }
    }

    /// Returns a collection of `MediaTypePreference`s specified by this HTTP message's `"Accept"` header.
    ///
    /// You can returns all `MediaType`s in this collection to check membership.
    ///
    ///     httpReq.accept.mediaTypes.contains(.html)
    ///
    /// Or you can compare preferences for two `MediaType`s.
    ///
    ///     let pref = httpReq.accept.comparePreference(for: .json, to: .html)
    ///
    public var accept: [MediaTypePreference] {
        return headers.firstValue(name: .accept).flatMap([MediaTypePreference].parse) ?? []
    }

    /// See `CustomDebugStringConvertible`
    public var debugDescription: String {
        return description
    }
}

/// Helper for encoding and decoding `Content` from an HTTP message.
///
///     req.content.decode(User.self)
///
/// See `Request` and `Response` for more information.
extension HTTPMessage {
    /// Serializes an `Encodable` object to this message using specific `HTTPMessageEncoder`.
    ///
    ///     try req.content.encode(user, using: JSONEncoder())
    ///
    /// - parameters:
    ///     - encodable: Instance of generic `Encodable` to serialize to this HTTP message.
    /// - throws: Errors during serialization.
    public mutating func encode<C>(_ encodable: C) throws
        where C: HTTPContent
    {
        try self.encode(encodable, as: C.defaultContentType)
    }
    
    
    /// Serializes an `Encodable` object to this message using specific `HTTPMessageEncoder`.
    ///
    ///     try req.content.encode(user, using: JSONEncoder())
    ///
    /// - parameters:
    ///     - encodable: Instance of generic `Encodable` to serialize to this HTTP message.
    ///     - encoder: Specific `HTTPMessageEncoder` to use.
    /// - throws: Errors during serialization.
    public mutating func encode<E>(_ encodable: E, as contentType: HTTPMediaType) throws
        where E: Encodable
    {
        try self.encode(encodable, using: self.requireEncoder(for: contentType))
    }
    
    /// Serializes an `Encodable` object to this message using specific `HTTPMessageEncoder`.
    ///
    ///     try req.content.encode(user, using: JSONEncoder())
    ///
    /// - parameters:
    ///     - encodable: Instance of generic `Encodable` to serialize to this HTTP message.
    ///     - encoder: Specific `HTTPMessageEncoder` to use.
    /// - throws: Errors during serialization.
    public mutating func encode<E>(_ encodable: E, using encoder: HTTPMessageEncoder) throws where E: Encodable {
        try encoder.encode(encodable, to: &self)
    }
    
    // MARK: Private
    
    /// Looks up a `HTTPMessageEncoder` for the supplied `MediaType`.
    private func requireEncoder(for mediaType: HTTPMediaType) throws -> HTTPMessageEncoder {
        return try HTTPContentConfiguration.global.requireEncoder(for: mediaType)
    }
}


/// Helper for encoding and decoding `Content` from an HTTP message.
///
///     req.content.decode(User.self)
///
/// See `Request` and `Response` for more information.
extension HTTPMessage {
    // MARK: Decode
    
    /// Parses a `Decodable` type from this HTTP message. This method supports streaming HTTP bodies (chunked) and can run asynchronously.
    /// See `syncDecode(_:)` for the non-streaming, synchronous version.
    ///
    ///     let user = req.content.decode(json: User.self, using: JSONDecoder())
    ///     print(user) // Future<User>
    ///
    /// This method accepts a custom `HTTPMessageDecoder`.
    ///
    /// - parameters:
    ///     - content: `Decodable` type to decode from this HTTP message.
    ///     - maxSize: Maximum streaming body size to support (does not apply to static bodies).
    ///     - decoder: Custom `HTTPMessageDecoder` to use.
    /// - returns: Future instance of the `Decodable` type.
    /// - throws: Any errors making the decoder for this media type or parsing the message.
    public func decode<D>(_ content: D.Type) throws -> D where D: Decodable {
        return try self.decode(D.self, using: self.requireDecoder())
    }
    
    /// Parses a `Decodable` type from this HTTP message. This method supports streaming HTTP bodies (chunked) and can run asynchronously.
    /// See `syncDecode(_:)` for the non-streaming, synchronous version.
    ///
    ///     let user = req.content.decode(json: User.self, using: JSONDecoder())
    ///     print(user) // Future<User>
    ///
    /// This method accepts a custom `HTTPMessageDecoder`.
    ///
    /// - parameters:
    ///     - content: `Decodable` type to decode from this HTTP message.
    ///     - maxSize: Maximum streaming body size to support (does not apply to static bodies).
    ///     - decoder: Custom `HTTPMessageDecoder` to use.
    /// - returns: Future instance of the `Decodable` type.
    /// - throws: Any errors making the decoder for this media type or parsing the message.
    public func decode<D>(_ content: D.Type, using decoder: HTTPMessageDecoder) throws -> D where D: Decodable {
        return try decoder.decode(D.self, from: self)
    }
    
    // MARK: Single Value
    
    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
    /// See `syncGet(_:at:)` for the streaming version.
    ///
    ///     let name = try req.content.get(String.self, at: "user", "name")
    ///     print(name) // Future<String>
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    ///     - maxSize: Maximum streaming body size to support (does not apply to non-streaming bodies).
    /// - returns: Future decoded `Decodable` value.
    public func decode<D>(_ type: D.Type = D.self, at keyPath: HTTPCodingKeyRepresentable...) throws -> D
        where D: Decodable
    {
        return try self.decode(D.self, at: keyPath)
    }
    
    /// Fetches a single `Decodable` value at the supplied key-path from this HTTP message's data.
    /// This method supports streaming HTTP bodies (chunked) and runs asynchronously.
    /// See `syncGet(_:at:)` for the streaming version.
    ///
    /// Note: This is the non-variadic version.
    ///
    ///     let name = try req.content.get(String.self, at: "user", "name")
    ///     print(name) // Future<String>
    ///
    /// - parameters:
    ///     - type: The `Decodable` value type to decode.
    ///     - keyPath: One or more key path components to the desired value.
    /// - returns: Future decoded `Decodable` value.
    public func decode<D>(_ type: D.Type = D.self, at keyPath: [HTTPCodingKeyRepresentable]) throws -> D
        where D: Decodable
    {
        return try self.requireDecoder().get(
            at: keyPath.map { $0.makeHTTPCodingKey() },
            from: self
        )
    }
    
    // MARK: Private
    
    /// Looks up a `HTTPMessageDecoder` for the supplied `MediaType`.
    private func requireDecoder() throws -> HTTPMessageDecoder {
        guard let count = self.body.count, count > 0 else {
            throw HTTPError(.noContent)
        }
        
        guard let contentType = self.contentType else {
            throw HTTPError(.noContentType)
        }
        
        return try HTTPContentConfiguration.global.requireDecoder(for: contentType)
    }
}


extension HTTPHeaders {
    /// Updates transport headers for current body.
    /// This should be called automatically be `HTTPRequest` and `HTTPResponse` when their `body` property is set.
    internal mutating func updateTransportHeaders(for body: HTTPBody) {
        if let count = body.count?.description {
            self.remove(name: .transferEncoding)
            if count != self[.contentLength].first {
                self.replaceOrAdd(name: .contentLength, value: count)
            }
        } else {
            self.remove(name: .contentLength)
            if self[.transferEncoding].first != "chunked" {
                self.replaceOrAdd(name: .transferEncoding, value: "chunked")
            }
        }
    }
}
