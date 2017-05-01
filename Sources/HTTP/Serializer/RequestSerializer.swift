import Transport

// we have hardcoded HTTP/1.1 since that is all this parser supports.
// an error will be thrown by the underlying serializer if different
// version is attempted to be serialized.
private let startLine: Bytes = [.space, .H, .T, .T, .P, .forwardSlash, .one, .period, .one]

public final class RequestSerializer<Stream: WriteableStream>: Serializer {
    typealias StreamType = Stream
    let stream: Stream
    public init(_ stream: Stream) {
        self.stream = stream
    }
    
    public func serialize(_ request: Request) throws {
        let message = try serialize(request as Message)
        
        let methodBytes = request.method.makeBytes()
        var length = methodBytes.count
            + 1 //space
            + request.uri.path.characters.count
        
        if let query = request.uri.query {
            length += 1 // question mark
                + query.characters.count
        }
        
        length += 11 // 11 bytes for the following characters: _HTTP/1.1\r\n
        length += message.count
        
        var buffer = Bytes()
        buffer.reserveCapacity(length)
        
        buffer += methodBytes
        buffer.append(.space)
        buffer += request.uri.path.makeBytes()
        if let query = request.uri.query {
            buffer.append(.questionMark)
            buffer += query.bytes
        }
        buffer += startLine
        buffer += Byte.crlf
        buffer += message
        
        try stream.write(buffer)
        try stream.flush()
        
        switch request.body {
        case .chunked(let closure):
            let chunkStream = ChunkStream(stream: stream)
            try closure(chunkStream)
            try stream.flush()
        case .data:
            break
        }
    }
}

extension Method {
    fileprivate func makeBytes() -> Bytes {
        switch self {
        case .connect:
            return [.C, .O, .N, .N, .E, .C, .T]
        case .delete:
            return [.D, .E, .L, .E, .T, .E]
        case .get:
            return [.G, .E, .T]
        case .head:
            return [.H, .E, .A, .D]
        case .options:
            return [.O, .P, .T, .I, .O, .N, .S]
        case .put:
            return [.P, .U, .T]
        case .patch:
            return [.P, .A, .T, .C, .H]
        case .post:
            return [.P, .O, .S, .T]
        case .trace:
            return [.T, .R, .A, .C, .E]
        case .other(let string):
            return string.makeBytes()
        }
    }
}
