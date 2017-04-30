import Transport
import CHTTP
import URI

/// Parses requests from a readable stream.
public final class RequestParser<Stream: ReadableStream>: CHTTPParser {
    // Internal variables to conform
    // to the C HTTP parser protocol.
    typealias StreamType = Stream
    let stream: Stream
    var parser: http_parser
    var settings: http_parser_settings
    var buffer: Bytes
    
    /// Creates a new Request parser.
    public init(stream: Stream) {
        self.stream = stream
        self.parser = http_parser()
        self.settings = http_parser_settings()
        http_parser_init(&parser, HTTP_REQUEST)
        self.buffer = Bytes()
        self.buffer.reserveCapacity(bufferSize)
    }
    
    /// Parses a Request from the stream.
    public func parse() throws -> Request {
        /// parse the message using the C HTTP parser.
        let results = try parseMessage()
        
        /// switch on the C method type from the parser
        let method: Method
        switch http_method(parser.method) {
        case HTTP_DELETE:
            method = .delete
        case HTTP_GET:
            method = .get
        case HTTP_HEAD:
            method = .head
        case HTTP_POST:
            method = .post
        case HTTP_PUT:
            method = .put
        case HTTP_CONNECT:
            method = .connect
        case HTTP_OPTIONS:
            method = .options
        case HTTP_TRACE:
            method = .trace
        case HTTP_PATCH:
            method = .patch
        default:
            /// custom method detected,
            /// convert the method into a string
            /// and use Engine's other type
            guard
                let pointer = http_method_str(http_method(parser.method)),
                let string = String(validatingUTF8: pointer)
            else {
                throw ParserError.invalidMessage
            }
            method = .other(method: string)
        }
        
        // parse the uri from the url bytes.
        var uri = URIParser.shared.parse(bytes: results.url)
        
        // set the host on the uri if it exists
        // in the headers
        if let hostname = results.headers[.host] {
            uri.hostname = hostname
        }
        
        // if there is no scheme, use http by default
        if uri.scheme.isEmpty == true {
            uri.scheme = "http"
        }
        
        // require a version to have been parsed
        guard let version = results.version else {
            throw ParserError.invalidMessage
        }
        
        // create the request
        let request = Request(
            method: method,
            uri: uri,
            version: version,
            headers: results.headers,
            body: .data(results.body)
        )
        return request
    }
}

// MARK: Settings

private var _bufferSize = 2048
extension RequestParser {
    public var bufferSize: Int {
        get {
            return _bufferSize
        }
        set {
            _bufferSize = newValue
        }
    }
}
