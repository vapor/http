import Transport

public final class RequestSerializer<Stream: WriteableStream>: Serializer {
    typealias StreamType = Stream
    let stream: Stream
    public init(_ stream: Stream) {
        self.stream = stream
    }
    
    public func serialize(_ request: Request) throws {
        let message = try serialize(request as Message)
        
        let methodBytes: Bytes
        switch request.method {
        case .connect:
            methodBytes = [.C, .O, .N, .N, .E, .C, .T]
        case .delete:
            methodBytes = [.D, .E, .L, .E, .T, .E]
        case .get:
            methodBytes = [.G, .E, .T]
        case .head:
            methodBytes = [.H, .E, .A, .D]
        case .options:
            methodBytes = [.O, .P, .T, .I, .O, .N, .S]
        case .put:
            methodBytes = [.P, .U, .T]
        case .patch:
            methodBytes = [.P, .A, .T, .C, .H]
        case .post:
            methodBytes = [.P, .O, .S, .T]
        case .trace:
            methodBytes = [.T, .R, .A, .C, .E]
        case .other(let string):
            methodBytes = string.makeBytes()
        }
        
        var length = methodBytes.count
            + 1 //space
            + request.uri.path.characters.count
        if let query = request.uri.query {
            length += 1 + query.characters.count
        }
        length += 11 // _HTTP/1.1\r\n
        length += message.count
        
        var buffer = Bytes()
        buffer.reserveCapacity(length)
        
        buffer += methodBytes
        buffer += [.space]
        buffer += request.uri.path.makeBytes()
        if let query = request.uri.query {
            buffer += [.questionMark] + query.bytes
        }
        buffer += [.space]
        buffer += [.H, .T, .T, .P, .forwardSlash, .one, .period, .one]
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
