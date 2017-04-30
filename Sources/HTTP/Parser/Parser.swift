import Transport
import CHTTP
import URI

extension UnsafePointer where Pointee == CChar {
    func makeBytes(length: Int) -> Bytes {
        let pointer = UnsafeBufferPointer(start: self, count: length)
        
        return pointer.baseAddress?.withMemoryRebound(to: UInt8.self, capacity: length) { pointer in
            let buffer = UnsafeBufferPointer(start: pointer, count: length)
            return Array(buffer)
        } ?? []
    }
    
    func makeString(length: Int) -> String {
        return makeBytes(length: length).makeString()
    }
}

internal protocol Parser: class {
    associatedtype StreamType: DuplexStream
    var stream: StreamType { get }
    var parser: http_parser { get set }
    var settings: http_parser_settings { get set }
}

extension Parser {
    internal func parseMessage() throws -> ParseResults {
        var results = ParseResults()
        parser.data = UnsafeMutableRawPointer(&results)
        
        settings.on_url = { parser, chunk, length in
            guard let results = ParseResults.from(parser) else {
                return 0
            }
            
            guard let bytes = chunk?.makeBytes(length: length) else {
                return 0
            }
            
            results.url += bytes
            
            return 0
        }
        
        settings.on_header_field = { parser, chunk, length in
            guard let results = ParseResults.from(parser) else {
                return 0
            }
            
            guard let bytes = chunk?.makeBytes(length: length) else {
                return 0
            }
            
            switch results.headerState {
            case .none:
                results.headerState = .key(bytes)
            case .value(let key, let value):
                results.headers[key] = value.makeString()
                results.headerState = .key(bytes)
            case .key(let key):
                results.headerState = .key(key + bytes)
            }
            
            return 0
        }
        
        settings.on_header_value = { parser, chunk, length in
            guard let results = ParseResults.from(parser) else {
                return 0
            }
            
            guard let bytes = chunk?.makeBytes(length: length) else {
                return 0
            }
            
            switch results.headerState {
            case .none:
                results.headerState = .none
            case .value(let key, let value):
                results.headerState = .value(key: key, value + bytes)
            case .key(let key):
                let headerKey = HeaderKey(key.makeString())
                results.headerState = .value(key: headerKey, bytes)
            }
            
            return 0
        }
        
        settings.on_headers_complete = { parser in
            guard let results = ParseResults.from(parser) else {
                return 0
            }
            
            switch results.headerState {
            case .value(let key, let value):
                results.headers[key] = value.makeString()
            default:
                break
            }
            
            return 0
        }
        
        settings.on_body = { parser, chunk, length in
            guard let results = ParseResults.from(parser) else {
                return 0
            }
            
            guard let bytes = chunk?.makeBytes(length: length) else {
                return 0
            }
            
            results.body += bytes
            return 0
        }
        
        settings.on_message_complete = { parser in
            guard let parser = parser else {
                return 0
            }
            
            guard let results = ParseResults.from(parser) else {
                return 0
            }
            
            results.isComplete = true
            results.uri = URIParser.shared.parse(bytes: results.url)
            
            if let hostname = results.headers[.host] {
                results.uri?.hostname = hostname
            }
            
            if results.uri?.scheme.isEmpty == true {
                results.uri?.scheme = "http"
            }
            
            // parse version
            let major = Int(parser.pointee.http_major)
            let minor = Int(parser.pointee.http_minor)
            results.version = Version(major: major, minor: minor)
            
            return 0
        }
        
        while !results.isComplete {
            let data = try stream.read(max: 2048)
            if data.count == 0 {
                throw ParserError.streamEmpty
            }
            try data.withUnsafeBytes { rawPointer in
                guard let pointer = rawPointer.baseAddress?.assumingMemoryBound(to: Int8.self) else {
                    return
                }
                
                let parsedCount = http_parser_execute(&parser, &settings, pointer, data.count)
                guard parsedCount == data.count else {
                    throw ParserError.invalidRequest
                }
            }
        }
        
        return results
    }

    func parsePeerAddress<Stream: InternetStream>(
        from stream: Stream,
        with headers: [HeaderKey: String]
    ) -> PeerAddress {
        let forwarded = headers["Forwarded"]
        let xForwardedFor = headers["X-Forwarded-For"]
        
        let streamAddress = "\(stream.hostname):\(stream.port)"
        
        return PeerAddress(
            forwarded: forwarded,
            xForwardedFor: xForwardedFor,
            stream: streamAddress
        )
    }
}
