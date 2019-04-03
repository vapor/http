/// Serializes `MultipartForm`s to `Data`.
///
/// See `MultipartParser` for more information about the multipart encoding.
public final class MultipartSerializer {
    /// Creates a new `MultipartSerializer`.
    public init() { }
    
    /// Serializes the `MultipartForm` to data.
    ///
    ///     let data = try MultipartSerializer().serialize(parts: [part], boundary: "123")
    ///     print(data) // multipart-encoded
    ///
    /// - parameters:
    ///     - parts: One or more `MultipartPart`s to serialize into `Data`.
    ///     - boundary: Multipart boundary to use for encoding. This must not appear anywhere in the encoded data.
    /// - throws: Any errors that may occur during serialization.
    /// - returns: `multipart`-encoded `Data`.
    public func serialize(parts: [MultipartPart], boundary: String) throws -> String {
        var body = ""
        var reserved = 0
        
        for part in parts {
            reserved += part.body.count
        }
        
        body.reserveCapacity(reserved + 512)
        for part in parts {
            body += "--" + boundary + "\r\n"
            for (key, val) in part.headers {
                body += key + ": " + val
                body += "\r\n"
            }
            body += "\r\n"
            body += String(decoding: part.body, as: UTF8.self)
            body += "\r\n"
        }
        body += "--" + boundary + "--\r\n"
        return body
    }
}
