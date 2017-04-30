import Transport

private let crlf: Bytes = [.carriageReturn, .newLine]

public final class Serializer<StreamType: DuplexStream> {
    let stream: StreamType
    public init(stream: StreamType) {
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
        buffer += crlf
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
        buffer += crlf
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

    private func serialize(_ message: Message) throws -> Bytes {
        var headers = message.headers
        headers.appendMetadata(for: message.body)
        
        var length = 0
        
        var headerBytes: [(key: Bytes, value: Bytes)] = []
        for (key, value) in headers {
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
            buffer += crlf
        }
        
        buffer += crlf
        buffer += bodyBytes
        
        return buffer
    }
}
