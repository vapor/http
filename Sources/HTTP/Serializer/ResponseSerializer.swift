import Transport

// we have hardcoded HTTP/1.1 since that is all this parser supports.
// an error will be thrown by the underlying serializer if different
// version is attempted to be serialized.
private let startLine: Bytes = [.H, .T, .T, .P, .forwardSlash, .one, .period, .one, .space]

public final class ResponseSerializer: ByteSerializer {
    var serialized: Int
    var offset: Int
    var pointer: Int
    var done: Bool
    
    public init() {
        serialized = 0
        offset = 0
        pointer = 0
        done = false
    }
    
    public func serialize(_ response: Response, into buffer: inout Bytes) throws -> Int {
        guard response.version.major == 1 && response.version.minor == 1 else {
            throw SerializerError.invalidVersion
        }
        
        if done {
            reset()
            done = false
            return 0
        }
    
        do {
            try fill(startLine, into: &buffer)
            try response.status.statusCode.description.utf8.forEach { byte in
                try fill(byte, into: &buffer)
            }
            try fill(.space, into: &buffer)
            try response.status.reasonPhrase.utf8.forEach { byte in
                try fill(byte, into: &buffer)
            }
            try fill(.carriageReturn, into: &buffer)
            try fill(.newLine, into: &buffer)
            
            try serialize(&response.headers, into: &buffer, for: response.body)
            
            done = true
            return pointer
        } catch ByteSerializerError.bufferFull {
            let interrupted = pointer
            pointer = 0
            return interrupted
        }
    }
}
