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

public final class BytesResponseSerializer {
    public init() {
        state = .ready
    }
    
    enum State {
        case ready
        case serializing(offset: Int)
        case done
    }
    
    var state: State
    
    public func serialize(_ response: Response, into buffer: inout Bytes) throws -> Int {
        guard response.version.major == 1 && response.version.minor == 1 else {
            throw SerializerError.invalidVersion
        }
        
        var pointer = 0
        
        startLine.forEach { byte in
            buffer[pointer] = byte
            pointer += 1
        }
        
        response.status.statusCode.description.makeBytes().forEach { byte in
            buffer[pointer] = byte
            pointer += 1
        }
        
        buffer[pointer] = .space
        pointer += 1
        
        response.status.reasonPhrase.makeBytes().forEach { byte in
            buffer[pointer] = byte
            pointer += 1
        }
        
        buffer[pointer] = .carriageReturn
        pointer += 1
        
        
        buffer[pointer] = .newLine
        pointer += 1
        
        switch response.body {
        case .chunked(_):
            response.headers[.contentLength] = nil
            response.headers[.transferEncoding] = "chunked"
        case .data(let bytes):
            response.headers[.contentLength] = bytes.count.description
            response.headers[.transferEncoding] = nil
        }
        
        try serialize(response.headers, into: &buffer, pointer: &pointer)
    
        switch response.body {
        case .chunked:
            break
            // FIXME:
            // let chunkStream = ChunkStream(stream: stream)
            // try closure(chunkStream)
            // try stream.flush()
        case .data(let bytes):
            bytes.forEach { byte in
                buffer[pointer] = byte
                pointer += 1
            }
        }

        return pointer
    }
    
    /// Serializes an HTTP message to bytes.
    internal func serialize(
        _ headers: [HeaderKey: String],
        into buffer: inout Bytes,
        pointer: inout Int
    ) throws {
        for (key, value) in headers {
            key.key.makeBytes().forEach { byte in
                buffer[pointer] = byte
                pointer += 1
            }
            
            buffer[pointer] = .colon
            pointer += 1
            
            buffer[pointer] = .space
            pointer += 1
            
            value.makeBytes().forEach { byte in
                buffer[pointer] = byte
                pointer += 1
            }
            
            buffer[pointer] = .carriageReturn
            pointer += 1
            
            buffer[pointer] = .newLine
            pointer += 1
        }
        buffer[pointer] = .carriageReturn
        pointer += 1
        
        buffer[pointer] = .newLine
        pointer += 1
    }

}
