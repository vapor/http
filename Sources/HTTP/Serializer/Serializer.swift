import Transport

/// Internal serializer protocol for turning a basic
/// HTTP message into bytes.
internal protocol ByteSerializer: class {
    var serialized: Int { get set }
    var offset: Int { get set }
    var pointer: Int { get set }
}

internal enum ByteSerializerError: Error {
    case bufferFull
}

extension ByteSerializer {
    func fill(_ bytes: Bytes, into buffer: inout Bytes) throws {
        for byte in bytes {
            try fill(byte, into: &buffer)
        }
    }
    
    func reset() {
        pointer = 0
        serialized = 0
        offset = 0
    }
    
    func fill(_ byte: Byte, into buffer: inout Bytes) throws {
        guard offset >= 0 else {
            offset += 1
            return
        }
        
        guard pointer < buffer.count else {
            serialized += pointer
            offset = -1 * serialized
            throw ByteSerializerError.bufferFull
        }
        
        buffer[pointer] = byte
        pointer += 1
    }
    
    func serialize(
        _ headers: inout [HeaderKey: String],
        into buffer: inout Bytes,
        for body: Body
    ) throws {
        switch body {
        case .chunked(_):
            headers[.contentLength] = nil
            headers[.transferEncoding] = "chunked"
        case .data(let bytes):
            headers[.contentLength] = bytes.count.description
            headers[.transferEncoding] = nil
        }
        
        for (key, value) in headers {
            try key.key.utf8.forEach { byte in
                try fill(byte, into: &buffer)
            }
            try fill(.colon, into: &buffer)
            try fill(.space, into: &buffer)
            try value.utf8.forEach { byte in
                try fill(byte, into: &buffer)
            }
            try fill(.carriageReturn, into: &buffer)
            try fill(.newLine, into: &buffer)
        }
        try fill(.carriageReturn, into: &buffer)
        try fill(.newLine, into: &buffer)
    }
}
