import Transport

// we have hardcoded HTTP/1.1 since that is all this parser supports.
// an error will be thrown by the underlying serializer if different
// version is attempted to be serialized.
private let startLine: Bytes = [.H, .T, .T, .P, .forwardSlash, .one, .period, .one, .space]

public final class ResponseSerializer<Stream: WriteableStream>: Serializer {
    typealias StreamType = Stream
    let stream: Stream
    public init(_ stream: Stream) {
        self.stream = stream
    }
    
    public func serialize(_ response: Response) throws {
        let message = try serialize(response as Message)
        
        let reasonPhrase = response.status.reasonPhrase.makeBytes()
        let length = 15 // 13 bytes for the following characters: HTTP/1.1_xxx_\r\n
            + reasonPhrase.count
            + message.count
        
        var buffer = Bytes()
        buffer.reserveCapacity(length)
        
        buffer += startLine
        buffer += response
            .status
            .statusCode
            .description
            .makeBytes()
        
        buffer.append(.space)
        buffer += reasonPhrase
        buffer += Byte.crlf
        buffer += message
        
        try stream.write(buffer)
        try stream.flush()
        
        switch response.body {
        case .chunked(let closure):
            let chunkStream = ChunkStream(stream: stream)
            try closure(chunkStream)
            try stream.flush()
        case .data:
            break
        }
    }
}
