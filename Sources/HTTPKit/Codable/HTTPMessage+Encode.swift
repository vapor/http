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
        return try HTTPContentConfig.global.requireEncoder(for: mediaType)
    }
}
