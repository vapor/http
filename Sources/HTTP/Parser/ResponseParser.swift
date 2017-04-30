import Transport
import CHTTP
import URI

/// Parses responses from a readable stream.
public final class ResponseParser<Stream: ReadableStream>: CHTTPParser {
    // Internal variables to conform
    // to the C HTTP parser protocol.
    typealias StreamType = Stream
    let stream: Stream
    var parser: http_parser
    var settings: http_parser_settings
    var buffer: Bytes
    
    /// Creates a new Response parser.
    public init(stream: Stream) {
        self.stream = stream
        self.parser = http_parser()
        self.settings = http_parser_settings()
        http_parser_init(&parser, HTTP_RESPONSE)
        self.buffer = Bytes()
        self.buffer.reserveCapacity(bufferSize)
    }
    
    /// Parses a Response from the stream.
    public func parse() throws -> Response {
        let results = try parseMessage()
        
        let status = Status(statusCode: Int(parser.status_code))
        
        guard let version = results.version else {
            throw ParserError.invalidMessage
        }
        
        let response = Response(
            version: version,
            status: status,
            headers: results.headers,
            body: .data(results.body)
        )
        
        return response
    }
}

// MARK: Settings

private var _bufferSize = 2048
extension ResponseParser {
    public var bufferSize: Int {
        get {
            return _bufferSize
        }
        set {
            _bufferSize = newValue
        }
    }
}
