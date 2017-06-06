import Transport

// we have hardcoded HTTP/1.1 since that is all this parser supports.
// an error will be thrown by the underlying serializer if different
// version is attempted to be serialized.
private let startLine: Bytes = [.space, .H, .T, .T, .P, .forwardSlash, .one, .period, .one]

public final class RequestSerializer: ByteSerializer {
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
    
    public func serialize(_ request: Request, into buffer: inout Bytes) throws -> Int {
        guard request.version.major == 1 && request.version.minor == 1 else {
            throw SerializerError.invalidVersion
        }
        
        if done {
            reset()
            done = false
            return 0
        }
        
        do {
            try fill(request.method.makeBytes(), into: &buffer)
            
            try fill(.space, into: &buffer)
            
            try request.uri.path.utf8.forEach { byte in
                try fill(byte, into: &buffer)
            }
            
            if let query = request.uri.query {
                try fill(.questionMark, into: &buffer)
                try fill(query.bytes, into: &buffer)
            }
            
            try fill(startLine, into: &buffer)
            
            try fill(.carriageReturn, into: &buffer)
            try fill(.newLine, into: &buffer)
            
            try serialize(&request.headers, into: &buffer, for: request.body)
            
            done = true
            return pointer
        } catch ByteSerializerError.bufferFull {
            let interrupted = pointer
            pointer = 0
            return interrupted
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
