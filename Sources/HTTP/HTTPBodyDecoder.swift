import Foundation

/// Capable of decoding a `Decodable` type from an `HTTPBody`.
///
/// `HTTPBodyDecoder`s must handle all cases of an `HTTPBody`, including streaming bodies.
/// Because the `HTTPBody` may be streaming (async), the `decode(_:from:on:)` method returns a `Future`.
///
///     let jsonDecoder: BodyDecoder = JSONDecoder()
///     let string = try jsonDecoder.decode(String.self, from: HTTPBody(string: "hello"), on: ...).wait()
///     print(string) /// "hello" from the HTTP body
///
/// The `HTTPBodyDecoder` protocol is what powers the `ContentContainer`s on `Request` and `Response`.
///
///     let string = try req.content.decode(String.self)
///     print(string) // Future<String>
///
/// `HTTPBodyDecoder`s can be registered with `ContentConfig` during the application config phase.
/// The decoders are associated with a `MediaType` when registered. When decoding content, the HTTP message's
/// `MediaType` is used to lookup an appropriate coder.
///
///     var contentConfig = ContentConfig.default()
///     contentConfig.use(decoder: JSONDecoder(), for: .json)
///     services.register(contentConfig)
///
public protocol HTTPBodyDecoder {
    /// Decodes the supplied `Decodable` type from an `HTTPBody`.
    ///
    ///     let jsonDecoder: BodyDecoder = JSONDecoder()
    ///     let string = try jsonDecoder.decode(String.self, from: HTTPBody(string: "hello"), on: ...).wait()
    ///     print(string) /// "hello" from the HTTP body
    ///
    /// - parameters:
    ///     - decodable: `Decodable` type to decode from the `HTTPBody`.
    ///     - from: `HTTPBody` to decode the `Decodable` type from. This `HTTPBody` may be static or streaming.
    ///     - maxSize: Maximum size in bytes for streaming bodies.
    ///     - on: `Worker` to perform asynchronous tasks on.
    /// - returns: `Future` containing the decoded type.
    /// - throws: Any errors that may have occurred while decoding the `HTTPBody`.
    func decode<D>(_ decodable: D.Type, from body: HTTPBody, maxSize: Int, on worker: Worker) throws -> Future<D>
    where D: Decodable
}

/// Capable of encoding an `Encodable` type to an `HTTPBody`.
///
/// `HTTPBodyEncoder`s may encode data into an `HTTPBody` using any of the available
/// cases (streaming, static, or other).
///
///     let jsonEncoder: BodyEncoder = JSONEncoder()
///     let body = try jsonEncoder.encodeBody(from: "hello")
///     print(body) /// HTTPBody containing the string "hello"
///
/// The `HTTPBodyEncoder` protocol is what powers the `ContentContainer`s on `Request` and `Response`.
///
///     try res.content.encode("hello", as: .plaintext)
///     print(res.mediaType) // .plaintext
///     print(res.http.body) // "hello"
///
/// `HTTPBodyEncoder`s can be registered with `ContentConfig` during the application config phase.
/// The encoders are associated with a `MediaType` when registered. When encoding content, the `Content`'s
/// default `MediaType` is used to lookup an appropriate coder. You can also choose to override the
/// `MediaType` when encoding.
///
///     var contentConfig = ContentConfig.default()
///     contentConfig.use(encoder: JSONEncoder(), for: .json)
///     services.register(contentConfig)
///
public protocol HTTPBodyEncoder {
    /// Encodes the supplied `Encodable` object to an `HTTPBody`.
    ///
    ///     let jsonEncoder: HTTPBodyEncoder = JSONEncoder()
    ///     let body = try jsonEncoder.encodeBody(from: "hello")
    ///     print(body) /// HTTPBody containing the string "hello"
    ///
    /// - parameters:
    ///     - from: `Encodable` object that will be encoded to the `HTTPBody`.
    /// - returns: Encoded HTTP body.
    /// - throws: Any errors that may occur while encoding the object.
    func encodeBody<E>(from encodable: E) throws -> HTTPBody where E: Encodable
}

// MARK: Default Conformances

extension JSONEncoder: HTTPBodyEncoder {
    /// See `HTTPBodyEncoder.encodeBody(from:)`
    public func encodeBody<E>(from encodable: E) throws -> HTTPBody where E : Encodable {
        return try HTTPBody(data: encode(encodable))
    }
}

extension JSONDecoder: HTTPBodyDecoder {
    /// See `HTTPBodyDecoder.decode(_:from:maxSize:on:)`
    public func decode<D>(_ decodable: D.Type, from body: HTTPBody, maxSize: Int = 65_536, on worker: Worker) throws -> EventLoopFuture<D> where D : Decodable {
        return body.consumeData(max: maxSize, on: worker).map(to: D.self) { data in
            return try self.decode(D.self, from: data)
        }
    }
}
