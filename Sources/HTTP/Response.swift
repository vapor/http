import Sockets

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

fileprivate let contentLengthHeader = [UInt8]("Content-Length: ".utf8)
fileprivate let eol = [UInt8]("\r\n".utf8)

fileprivate let upgradeSignature = [UInt8]("HTTP/1.1 101 Switching Protocols\r\n".utf8)
fileprivate let okSignature = [UInt8]("HTTP/1.1 200 OK\r\n".utf8)
fileprivate let notFoundSignature = [UInt8]("HTTP/1.1 404 NOT FOUND\r\n".utf8)

/// The HTTP response status
///
/// TODO: Add more status codes
public enum Status : ExpressibleByIntegerLiteral {
    /// upgrade is used for upgrading the connection to a new protocol, such as WebSocket or HTTP/2
    case upgrade
    
    /// A successful response
    case ok
    
    /// The resource has not been found
    case notFound
    
    /// An internal error occurred
    case internalServerError
    
    /// Something yet to be implemented
    case custom(code: Int, message: String)
    
    /// Checks of two Statuses are equal
    public static func ==(lhs: Status, rhs: Status) -> Bool {
        return lhs.code == rhs.code
    }
    
    /// The HTTP status code
    public var code: Int {
        switch self {
        case .upgrade: return 101
        case .ok: return 200
        case .notFound: return 404
        case .internalServerError: return 500
        case .custom(let code, _): return code
        }
    }
    
    /// Returns a signature, for internal purposes only
    fileprivate var signature: [UInt8] {
        switch self {
        case .upgrade:
            return upgradeSignature
        case .ok:
            return okSignature
        case .notFound:
            return notFoundSignature
        case .internalServerError:
            return [UInt8]("HTTP/1.1 500 INTERNAL SERVER ERROR\r\n".utf8)
        case .custom(let code, let message):
            return code.description.utf8 + [0x20] + message.utf8
        }
    }
    
    /// Creates a new (custom) status code
    public init(_ code: Int, message: String = "") {
        switch code {
        case 101: self = .upgrade
        case 200: self = .ok
        case 404: self = .notFound
        case 500: self = .internalServerError
        default: self = .custom(code: code, message: message)
        }
    }
    
    /// Creates a new status from an integer literal
    public init(integerLiteral value: Int) {
        self.init(value)
    }
}

/// An HTTP response
///
/// To be returned to a client
public class Response : Codable {
    /// Encodes the response to a dictionary-type
    public func encode(to encoder: Encoder) throws {
        let body = try self.body?.makeBody()
        var container = encoder.container(keyedBy: Response.CodingKeys.self)
        
        try container.encode(status, forKey: .status)
        try container.encode(headers, forKey: .headers)
        try container.encode(body, forKey: .body)
    }
    
    /// Decodes the response from a dictionary-type
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Response.CodingKeys.self)
        
        self.status = try container.decode(Status.self, forKey: .status)
        self.headers = try container.decode(Headers.self, forKey: .headers)
        self.body = try container.decodeIfPresent(Body.self, forKey: .body)
    }
    
    /// Used internally for encoding/decoding purposes
    fileprivate enum CodingKeys : String, Swift.CodingKey {
        case status, headers, body
    }
    
    /// The resulting status
    public var status: Status
    
    /// The headers to be responded with
    public var headers: Headers
    
    /// The body, can contain anything you want to return
    ///
    /// An image, JSON, PDF, HTML etc..
    ///
    /// Must be nil for requests like `HEAD`
    public var body: BodyRepresentable?
    
    /// Creates a new bodyless response
    public init(status: Status, headers: Headers = Headers()) {
        self.status = status
        self.headers = headers
    }
    
    /// Creates a new response with a body
    public init(status: Status, headers: Headers = Headers(), body: BodyRepresentable) {
        self.status = status
        self.headers = headers
        self.body = body
    }
}

/// HTTP Remotes are used for receiving errors and responses
///
/// This is usually a socket, but may also be another source with bidirectional communication
public protocol HTTPRemote {
    func send(_ response: Response) throws
    func error(_ error: Error)
}

/// Makes the TCPClient an HTTPRemote
extension RemoteClient : HTTPRemote {
    /// Handles the error and closes the connection
    public func error(_ error: Error) {
        self.close()
    }
    
    /// Sends the serialized HTTP response over the socket
    public func send(_ response: Response) throws {
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: 65_536)
        pointer.initialize(to: 0, count: 65_536)
        
        defer {
            pointer.deinitialize(count: 65_536)
            pointer.deallocate(capacity: 65_536)
        }
        
        let signature = response.status.signature
        var consumed = signature.count
        
        memcpy(pointer, signature, consumed)
        
        guard response.headers.buffer.count &+ consumed &+ 2 < 65_536, let headersAddress = response.headers.buffer.baseAddress else {
            // TODO: Fix this
            fatalError()
        }
        
        // headers
        memcpy(pointer.advanced(by: consumed), headersAddress, response.headers.buffer.count)
        
        consumed = consumed &+ response.headers.buffer.count
        
        // length header
        
        memcpy(pointer.advanced(by: consumed), contentLengthHeader, contentLengthHeader.count)
        
        consumed = consumed &+ contentLengthHeader.count
        
        let body = try response.body?.makeBody()
        
        let bodyLengthWithEOL = [UInt8]((body?.buffer.count ?? 0).description.utf8) + eol
        
        memcpy(pointer.advanced(by: consumed), bodyLengthWithEOL, bodyLengthWithEOL.count)
        
        consumed = consumed &+ bodyLengthWithEOL.count
        
        // Headers end
        memcpy(pointer.advanced(by: consumed), eol, eol.count)
        
        consumed = consumed &+ eol.count
        
        if let body = body, body.buffer.count &- consumed < 65_536, let baseAddress = body.buffer.baseAddress {
            memcpy(pointer.advanced(by: consumed), baseAddress, body.buffer.count)
            consumed = consumed &+ body.buffer.count
            
            try self.write(contentsAt: pointer, withLengthOf: consumed)
        } else {
            try self.write(contentsAt: pointer, withLengthOf: consumed)
            
            if let body = body, let baseAddress = body.buffer.baseAddress {
                try self.write(contentsAt: baseAddress, withLengthOf: body.buffer.count)
            }
        }
    }
}

extension Status : Codable {
    /// Makes status encodable by encoding it to an int
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.code)
    }
    
    /// Makes status decodable by decoding it from an int
    public init(from decoder: Decoder) throws {
        self.init(try decoder.singleValueContainer().decode(Int.self))
    }
}

/// Can be representable as a response
public protocol ResponseRepresentable {
    func makeResponse() throws -> Response
}


