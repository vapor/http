import Transport

public final class ResponseSerializer<Stream: WriteableStream>: Serializer {
    typealias StreamType = Stream
    let stream: Stream
    public init(_ stream: Stream) {
        self.stream = stream
    }
    
    public func serialize(_ response: Response) throws {
        let message = try serialize(response as Message)
        
        let reasonPhrase = response.status.reasonPhrase.makeBytes()
        let length = 5 // HTTP/
            + 8 // 1.1_xxx_
            + reasonPhrase.count
            + 2 // \r\n
            + message.count
        
        var buffer = Bytes()
        buffer.reserveCapacity(length)
        
        buffer += [.H, .T, .T, .P, .forwardSlash, .one, .period, .one, .space]
        buffer += response.status.statusCode.description.makeBytes()
        buffer += [.space]
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
