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
        guard let contentType = self.contentType else {
            if self.body.count == 0 {
                fatalError()
                #warning("TODO:")
                // throw Abort(.unsupportedMediaType, reason: "No content.", identifier: "httpContentType")
            } else {
                fatalError()
                #warning("TODO:")
                // throw Abort(.unsupportedMediaType, reason: "No content-type header.", identifier: "httpContentType")
            }
        }
        return try HTTPContentConfig.global.requireDecoder(for: contentType)
    }
}
