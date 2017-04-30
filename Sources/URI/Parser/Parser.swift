import Core
import Transport
import CHTTP

/// Parses URIs from bytes.
public final class URIParser {
    /// Use a shared parser since URI parser doesn't
    /// require special configuration
    public static let shared = URIParser()
    
    /// Creates a new URI parser.
    public init() {}
    
    /// Parses a URI from the supplied bytes.
    public func parse(bytes: Bytes) -> URI {
        // create url results struct
        var url = http_parser_url()
        http_parser_url_init(&url)
        
        // parse url
        http_parser_parse_url(bytes.makeCBytes(), bytes.count, 0, &url)
        
        // fetch offsets from result
        let (scheme, hostname, port, path, query, fragment, userinfo) = url.field_data
        
        // parse uri info
        let info: URI.UserInfo?
        if userinfo.len > 0, let bytes = bytes.bytes(for: userinfo) {
            let parts = bytes.split(separator: .colon, maxSplits: 1)
            switch parts.count {
            case 2:
                info = URI.UserInfo(
                    username: parts[0].makeString(),
                    info: parts[1].makeString()
                )
            case 1:
                info = URI.UserInfo(username: parts[0].makeString())
            default:
                info = nil
            }
        } else {
            info = nil
        }
        
        // sets a port if one was supplied
        // in the url bytes
        let p: Port?
        if let bytes = bytes.string(for: port) {
            p = Port(bytes)
        } else {
            p = nil
        }
        
        // create uri
        let uri = URI(
            scheme: bytes.string(for: scheme) ?? "",
            userInfo: info,
            hostname: bytes.string(for: hostname) ?? "",
            port: p,
            path: bytes.string(for: path) ?? "",
            query: bytes.string(for: query),
            fragment: bytes.string(for: fragment)
        )
        return uri
    }
}

// MARK: Convenience

extension URIParser {
    public func parse(_ bytes: BytesConvertible) throws -> URI {
        return try parse(bytes: bytes.makeBytes())
    }
}

// MARK: Utilities

extension Array where Iterator.Element == Byte {
    /// Creates a C pointer from a Bytes array.
    func makeCBytes() -> UnsafePointer<CChar>? {
        return self.withUnsafeBytes { rawPointer in
            return rawPointer.baseAddress?.assumingMemoryBound(to: CChar.self)
        }
    }
    
    /// Creates a string from the supplied field data offsets
    func string(for data: http_parser_url_field_data) -> String? {
        return bytes(for: data)?.makeString()
    }
    
    /// Creates bytes from the supplied field data offset.
    func bytes(for data: http_parser_url_field_data) -> Bytes? {
        return bytes(from: data.off, length: data.len)
    }
    
    /// Creates bytes from the supplied offset and length
    func bytes(from: UInt16, length: UInt16) -> Bytes? {
        return bytes(from: Int(from), length: Int(length))
    }
    
    /// Creates bytes from the supplied offset and length
    func bytes(from: Int, length: Int) -> Bytes? {
        guard length > 0 else {
            return nil
        }
        return self[from..<(from+length)].array
    }
}
