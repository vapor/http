import Dispatch
import Bits
/*
 https://tools.ietf.org/html/rfc3986#section-3
 
 URI         = scheme ":" hier-part [ "?" query ] [ "#" fragment ]
 
 The following are two example URIs and their component parts:
 
 foo://example.com:8042/over/there?name=ferret#nose
 \_/   \______________/\_________/ \_________/ \__/
 |           |            |            |        |
 scheme     authority       path        query   fragment
 |   _____________________|__
 / \ /                        \
 urn:example:animal:ferret:nose
 
 [Learn More →](https://docs.vapor.codes/3.0/http/uri/)
 */
public struct URI: Codable {
    /// A lazy buffer
    var buffer: [UInt8]
    
    // https://tools.ietf.org/html/rfc3986#section-3.1
    public var scheme: String? {
        get {
            return self.parse(.scheme)
        }
        set {
            update(.scheme, to: newValue?.description)
        }
    }
    
    // https://tools.ietf.org/html/rfc3986#section-3.2.1
    public var userInfo: UserInfo? {
        get {
            guard let userInfo = self.parse(.userinfo)?.split(separator: ":") else {
                return nil
            }
            
            if userInfo.count == 2 {
                return UserInfo(
                    username: String(userInfo[0]),
                    info: String(userInfo[1])
                )
            } else {
                return UserInfo(
                    username: String(userInfo[0])
                )
            }
        }
        set {
            update(.hostname, to: newValue?.description)
        }
    }
    
    // https://tools.ietf.org/html/rfc3986#section-3.2.2
    public var hostname: String? {
        get {
            return self.parse(.hostname)
        }
        set {
            update(.hostname, to: newValue?.description)
        }
    }
    
    // https://tools.ietf.org/html/rfc3986#section-3.2.3
    public var port: Port? {
        get {
            guard let port = parse(.port) else { return nil }
            return Port(port)
        }
        set {
            update(.port, to: newValue?.description)
        }
    }
    
    // https://tools.ietf.org/html/rfc3986#section-3.3
    public var pathBytes: ArraySlice<UInt8> {
        guard let (start, end) = self.boundaries(of: .path) else {
            return []
        }
        
        return self.buffer[start..<end]
    }
    
    // https://tools.ietf.org/html/rfc3986#section-3.3
    public var path: String {
        get {
            return String(bytes: pathBytes, encoding: .utf8) ?? ""
        }
        set {
            update(.path, to: newValue)
        }
    }
    
    // https://tools.ietf.org/html/rfc3986#section-3.4
    public var query: String? {
        get {
            return parse(.query)
        }
        set {
            update(.query, to: newValue?.description)
        }
    }
    
    // https://tools.ietf.org/html/rfc3986#section-3.5
    public var fragment: String? {
        get {
            return parse(.fragment)
        }
        set {
            update(.fragment, to: newValue?.description)
        }
    }
    
    internal init(buffer: [UInt8]) {
        self.buffer = buffer
    }
    
    /// Decodes URI from a String
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        self.init(stringLiteral: try container.decode(String.self))
    }
    
    /// Encodes URI to a String
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

extension URI {
    /// Creates a new URI
    public init(
        scheme: String? = nil,
        userInfo: UserInfo? = nil,
        hostname: String? = nil,
        port: Port? = nil,
        path: String = "/",
        query: String? = nil,
        fragment: String? = nil
    ) {
        var buffer = [UInt8]()
        buffer.reserveCapacity(256)
        
        if let scheme = scheme {
            buffer.append(contentsOf: scheme.utf8)
            if scheme.last != "/" && scheme.last != ":" {
                buffer.append(contentsOf: [.colon, .forwardSlash, .forwardSlash])
            }
        }
        
        if let userInfo = userInfo {
            buffer.append(contentsOf: userInfo.description.utf8)
            buffer.append(.at)
        }
        
        if let hostname = hostname {
            buffer.append(contentsOf: hostname.utf8)
        }
        
        if let port = port {
            if hostname != nil {
                buffer.append(.colon)
            }
            
            buffer.append(contentsOf: port.description.utf8)
        }
        
        if path.first != "/" {
            buffer.append(.forwardSlash)
        }
        
        buffer.append(contentsOf: path.utf8)
        
        if let query = query {
            buffer.append(.questionMark)
            buffer.append(contentsOf: query.utf8)
        }
        
        if let fragment = fragment {
            buffer.append(.numberSign)
            buffer.append(contentsOf: fragment.utf8)
        }
        
        self.init(buffer: buffer)
    }
}

extension URI {
    /// https://tools.ietf.org/html/rfc3986#section-3.2.1
    public struct UserInfo: Codable {
        public let username: String
        public let info: String?

        public init(username: String, info: String? = nil) {
            self.username = username
            self.info = info
        }
    }
}

extension URI.UserInfo: CustomStringConvertible {
    public var description: String {
        var d = username
        if let info = info {
            d += ":\(info)"
        }
        return d
    }
}

public typealias Port = UInt16

extension URI {
    /// Default ports known to correspond with given schemes.
    /// Expand as possible
    public static let defaultPorts: [String: Port] = [
        "http": 80,
        "https": 443,
        "ws": 80,
        "wss": 443
    ]
    
    /// The default port for scheme associated with this URI if known
    public var defaultPort: Port? {
        guard let scheme = scheme else {
            return nil
        }
        return URI.defaultPorts[scheme]
    }
}

extension URI: RawRepresentable, CustomStringConvertible {
    public typealias RawValue = String

    public init?(rawValue: String) {
        self = .init(stringLiteral: rawValue)
    }
    
    public var rawValue: String {
        var uri = ""
        
        if let scheme = scheme {
            uri += scheme + "://"
        }
        
        if let userInfo = userInfo {
            uri += userInfo.description + "@"
        }
        
        if let hostname = hostname {
            uri += hostname
        }
        
        if let port = port {
            uri += ":" + port.description
        }
        
        uri += path
        
        if let query = query {
            uri += "?" + query
        }
        
        if let fragment = fragment {
            uri += "#" + fragment
        }
        
        return uri
    }

    public var description: String {
        return self.rawValue
    }
}

// MARK: String literal
import Foundation

extension URI: ExpressibleByStringLiteral {
    public init(_ string: String) {
        self = URI(buffer: Array(string.utf8))
    }
    public init(stringLiteral value: String) {
        self = URI(buffer: Array(value.utf8))
    }
}


