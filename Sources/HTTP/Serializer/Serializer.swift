import Transport

/// Internal serializer protocol for turning a basic
/// HTTP message into bytes.
internal protocol Serializer {
    associatedtype StreamType: WriteableStream
    var stream: StreamType { get }
}

extension Serializer {
    /// Serializes an HTTP message to bytes.
    internal func serialize(_ message: Message) throws -> Bytes {
        var length = 0
        
        switch message.body {
        case .chunked(_):
            message.headers[.contentLength] = nil
            message.headers[.transferEncoding] = "chunked"
        case .data(let bytes):
            message.headers[.contentLength] = bytes.count.description
            message.headers[.transferEncoding] = nil
        }
        
        var headerBytes: [(key: Bytes, value: Bytes)] = []
        for (key, value) in message.headers {
            let k = key.key.makeBytes()
            let v = value.makeBytes()
            length += k.count + 2 + v.count + 2
            headerBytes.append((key: k, value: v))
        }
        length += 2
        
        let bodyBytes: Bytes
        switch message.body {
        case .chunked:
            bodyBytes = []
        case .data(let bytes):
            length += bytes.count
            bodyBytes = bytes
        }
        
        var buffer = Bytes()
        buffer.reserveCapacity(length)
        
        for header in headerBytes {
            buffer += header.key
            buffer += [.colon, .space]
            buffer += header.value
            buffer += Byte.crlf
        }
        
        buffer += Byte.crlf
        buffer += bodyBytes
        
        return buffer
    }
}

