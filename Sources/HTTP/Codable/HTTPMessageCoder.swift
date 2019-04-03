import Foundation

/// Capable of decoding a `Decodable` type from an `HTTPBody`.
///
/// `HTTPMessageDecoder`s must handle all cases of an `HTTPBody`, including streaming bodies.
/// Because the `HTTPBody` may be streaming (async), the `decode(_:from:on:)` method returns a `Future`.
///
///     let jsonDecoder: BodyDecoder = JSONDecoder()
///     let string = try jsonDecoder.decode(String.self, from: HTTPBody(string: "hello"), on: ...).wait()
///     print(string) /// "hello" from the HTTP body
///
/// The `HTTPMessageDecoder` protocol is what powers the `ContentContainer`s on `Request` and `Response`.
///
///     let string = try req.content.decode(String.self)
///     print(string) // Future<String>
///
/// `HTTPMessageDecoder`s can be registered with `ContentConfig` during the application config phase.
/// The decoders are associated with a `MediaType` when registered. When decoding content, the HTTP message's
/// `MediaType` is used to lookup an appropriate coder.
///
///     var contentConfig = ContentConfig.default()
///     contentConfig.use(decoder: JSONDecoder(), for: .json)
///     services.register(contentConfig)
///
public protocol HTTPMessageDecoder {
    /// Decodes the supplied `Decodable` type from an `HTTPMessage`.
    ///
    ///     let jsonDecoder: BodyDecoder = JSONDecoder()
    ///     let string = try jsonDecoder.decode(String.self, from: httpReq, on: ...).wait()
    ///     print(string) /// "hello" from the HTTP body
    ///
    /// - parameters:
    ///     - decodable: `Decodable` type to decode from the `HTTPBody`.
    ///     - from: `HTTPMessage` to decode the `Decodable` type from. The `HTTPBody` may be static or streaming.
    ///     - maxSize: Maximum size in bytes for streaming bodies.
    ///     - on: `Worker` to perform asynchronous tasks on.
    /// - returns: `Future` containing the decoded type.
    /// - throws: Any errors that may have occurred while decoding the `HTTPMessage`.
    func decode<D, M>(_ decodable: D.Type, from message: M, maxSize: Int, on worker: Worker) throws -> Future<D>
        where D: Decodable, M: HTTPMessage
}

extension HTTPMessageDecoder {
    /// See `HTTPMessageDecoder`.
    /// - note: This method will use a default max size of 1MB.
    public func decode<D, M>(_ decodable: D.Type, from message: M, on worker: Worker) throws -> Future<D>
        where D: Decodable, M: HTTPMessage
    {
        return try decode(D.self, from: message, maxSize: 1_000_000, on: worker)
    }
}

/// Capable of encoding an `Encodable` type to an `HTTPBody`.
///
/// `HTTPMessageEncoder`s may encode data into an `HTTPBody` using any of the available
/// cases (streaming, static, or other).
///
///     let jsonEncoder: BodyEncoder = JSONEncoder()
///     let body = try jsonEncoder.encodeBody(from: "hello")
///     print(body) /// HTTPBody containing the string "hello"
///
/// The `HTTPMessageEncoder` protocol is what powers the `ContentContainer`s on `Request` and `Response`.
///
///     try res.content.encode("hello", as: .plaintext)
///     print(res.mediaType) // .plaintext
///     print(res.http.body) // "hello"
///
/// `HTTPMessageEncoder`s can be registered with `ContentConfig` during the application config phase.
/// The encoders are associated with a `MediaType` when registered. When encoding content, the `Content`'s
/// default `MediaType` is used to lookup an appropriate coder. You can also choose to override the
/// `MediaType` when encoding.
///
///     var contentConfig = ContentConfig.default()
///     contentConfig.use(encoder: JSONEncoder(), for: .json)
///     services.register(contentConfig)
///
public protocol HTTPMessageEncoder {
    /// Encodes the supplied `Encodable` object to an `HTTPMessage`.
    ///
    ///     let jsonEncoder: HTTPMessageEncoder = JSONEncoder()
    ///     let body = try jsonEncoder.encodeBody(from: "hello")
    ///     print(body) /// HTTPBody containing the string "hello"
    ///
    /// - parameters:
    ///     - from: `Encodable` object that will be encoded to the `HTTPMessage`.
    /// - returns: Encoded HTTP body.
    /// - throws: Any errors that may occur while encoding the object.
    func encode<E, M>(_ encodable: E, to message: inout M, on worker: Worker) throws
        where E: Encodable, M: HTTPMessage
}

// MARK: Default Conformances

extension JSONDecoder: HTTPMessageDecoder {
    /// See `HTTPMessageDecoder`
    public func decode<D, M>(_ decodable: D.Type, from message: M, maxSize: Int, on worker: Worker) throws -> EventLoopFuture<D>
        where D: Decodable, M: HTTPMessage
    {
        guard message.contentType == .json || message.contentType == .jsonAPI else {
            throw HTTPError(identifier: "contentType", reason: "HTTP message did not have JSON-compatible content-type.")
        }
        return message.body.consumeData(max: maxSize, on: worker).map(to: D.self) { data in
            return try self.decode(D.self, from: data)
        }
    }
}

extension JSONEncoder: HTTPMessageEncoder {
    /// See `HTTPMessageEncoder`
    public func encode<E, M>(_ encodable: E, to message: inout M, on worker: Worker) throws
        where E: Encodable, M: HTTPMessage
    {
        message.contentType = .json
        message.body = try HTTPBody(data: encode(encodable))
    }
}
