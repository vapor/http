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

extension Array where Iterator.Element == Bytes {
}

extension Byte {
}

fileprivate enum InternalParseError: Error {
    case bufferFull
}

public final class BytesResponseSerializer {
    public init() {
        serialized = 0
        offset = 0
        pointer = 0
        done = false
    }
    
    var serialized: Int
    var offset: Int
    var pointer: Int
    var done: Bool
    
    func fill(_ bytes: Bytes, into buffer: inout Bytes) throws {
        for byte in bytes {
            try fill(byte, into: &buffer)
        }
    }
    
    
    func fill(_ byte: Byte, into buffer: inout Bytes) throws {
        guard offset >= 0 else {
            offset += 1
            return
        }
    
        guard pointer < buffer.count else {
            serialized += pointer
            offset = -1 * serialized
            throw InternalParseError.bufferFull
        }
        
        buffer[pointer] = byte
        pointer += 1
    }
    
    public func serialize(_ response: Response, into buffer: inout Bytes) throws -> Int {
        guard response.version.major == 1 && response.version.minor == 1 else {
            throw SerializerError.invalidVersion
        }
        
        if done {
            // reset
            done = false
            pointer = 0
            serialized = 0
            offset = 0
            return 0
        }
    
        do {
            try fill(startLine, into: &buffer)
            try fill(response.status.statusCode.description.makeBytes(), into: &buffer)
            try fill(.space, into: &buffer)
            try fill(response.status.reasonPhrase.makeBytes(), into: &buffer)
            try fill(.carriageReturn, into: &buffer)
            try fill(.newLine, into: &buffer)
            
            switch response.body {
            case .chunked(_):
                response.headers[.contentLength] = nil
                response.headers[.transferEncoding] = "chunked"
            case .data(let bytes):
                response.headers[.contentLength] = bytes.count.description
                response.headers[.transferEncoding] = nil
            }
            
            for (key, value) in response.headers {
                try fill(key.key.makeBytes(), into: &buffer)
                try fill(.colon, into: &buffer)
                try fill(.space, into: &buffer)
                try fill(value.makeBytes(), into: &buffer)
                try fill(.carriageReturn, into: &buffer)
                try fill(.newLine, into: &buffer)
            }
            try fill(.carriageReturn, into: &buffer)
            try fill(.newLine, into: &buffer)
            
            switch response.body {
            case .chunked:
                break
                // FIXME:
                // let chunkStream = ChunkStream(stream: stream)
                // try closure(chunkStream)
                // try stream.flush()
            case .data(let bytes):
                try fill(bytes, into: &buffer)
            }
            
            done = true
            return pointer
        } catch InternalParseError.bufferFull {
            let interrupted = pointer
            pointer = 0
            return interrupted
        }
    }
}
