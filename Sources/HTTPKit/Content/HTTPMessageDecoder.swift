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
    /// - returns: `Future` containing the decoded type.
    /// - throws: Any errors that may have occurred while decoding the `HTTPMessage`.
    func decode<D, M>(_ decodable: D.Type, from message: M) throws -> D
        where D: Decodable, M: HTTPMessage
}

// MARK: Default Conformances

extension JSONDecoder: HTTPMessageDecoder {
    /// See `HTTPMessageDecoder`
    public func decode<D, M>(_ decodable: D.Type, from message: M) throws -> D
        where D: Decodable, M: HTTPMessage
    {
        guard message.contentType == .json || message.contentType == .jsonAPI else {
            throw HTTPError(.unknownContentType)
        }
        guard let data = message.body.data else {
            throw HTTPError(.noContent)
        }
        return try self.decode(D.self, from: data)
    }
}
