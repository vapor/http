import Foundation

#warning("TODO: add HTTPStreamingMessageEncoder / HTTPStreamingMessageDecoder")

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
    ///     var req = HTTPRequest()
    ///     let body = try JSONEncoder().encode("hello", to: req)
    ///     print(body) /// HTTPBody containing the string "hello"
    ///
    /// - parameters:
    ///     - from: `Encodable` object that will be encoded to the `HTTPMessage`.
    /// - returns: Encoded HTTP body.
    /// - throws: Any errors that may occur while encoding the object.
    func encode<E, M>(_ encodable: E, to message: inout M) throws
        where E: Encodable, M: HTTPMessage
}

// MARK: Default Conformances

extension JSONEncoder: HTTPMessageEncoder {
    /// See `HTTPMessageEncoder`
    public func encode<E, M>(_ encodable: E, to message: inout M) throws
        where E: Encodable, M: HTTPMessage
    {
        message.contentType = .json
        message.body = try HTTPBody(data: encode(encodable))
    }
}
