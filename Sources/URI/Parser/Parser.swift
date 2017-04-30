import Core
import Transport
import CHTTP

public final class URIParser {
    public static let shared = URIParser()
    
    public init() {}
    
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

extension URIParser {
    public func parse(_ bytes: BytesConvertible) throws -> URI {
        return try parse(bytes: bytes.makeBytes())
    }
}

extension Array where Iterator.Element == Byte {
    func makeCBytes() -> UnsafePointer<CChar>? {
        return self.withUnsafeBytes { rawPointer in
            return rawPointer.baseAddress?.assumingMemoryBound(to: CChar.self)
        }
    }
    
    func string(for data: http_parser_url_field_data) -> String? {
        return bytes(from: data.off, length: data.len)?.makeString()
    }
    
    func bytes(for data: http_parser_url_field_data) -> Bytes? {
        return bytes(from: data.off, length: data.len)
    }
    
    func bytes(from: UInt16, length: UInt16) -> Bytes? {
        return bytes(from: Int(from), length: Int(length))
    }
    
    func bytes(from: Int, length: Int) -> Bytes? {
        guard length > 0 else {
            return nil
        }
        return self[from..<(from+length)].array
    }
}
