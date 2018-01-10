import Bits
import CHTTP
import Async
import Dispatch
import Foundation

/// Parses requests from a readable stream.
public final class HTTPRequestParser: CHTTPParser {
    public typealias Output = Message
    
    /// See CParser.Message
    public typealias Message = HTTPRequest

    /// See CHTTPParser.parserType
    static let parserType: http_parser_type = HTTP_REQUEST

    // Internal variables to conform
    // to the C HTTP parser protocol.
    var parser: http_parser
    var settings: http_parser_settings
    var state:  CHTTPParserState

    /// The maxiumum possible body size
    /// larger sizes will result in an error
    public var maxMessageSize: Int?
    public var maxHeaderSize: Int?
    public var maxBodySize: Int?

    var upstream: ConnectionContext?
    var downstream: AnyInputStream<HTTPRequest>?
    var downstreamDemand: UInt
    public var message: Message?
    public var messageBodyCompleted: Bool

    /// Creates a new Request parser.
    public init() {
        self.maxMessageSize = 10_000_000
        self.maxHeaderSize = 100_000
        self.maxBodySize = 10_000_000
        
        self.parser = http_parser()
        self.settings = http_parser_settings()
        self.state = .ready
        self.downstreamDemand = 0
        self.messageBodyCompleted = false
        reset()
    }

    func makeMessage(from results: CParseResults) throws -> HTTPRequest {
        // require a version to have been parsed
        guard
            let version = results.version,
            let headers = results.headers
        else {
            throw HTTPError.invalidMessage()
        }
        
        /// switch on the C method type from the parser
        let method: HTTPMethod
        switch http_method(parser.method) {
        case HTTP_DELETE:
            method = .delete
        case HTTP_GET:
            method = .get
        case HTTP_POST:
            method = .post
        case HTTP_PUT:
            method = .put
        case HTTP_OPTIONS:
            method = .options
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
                throw HTTPError.invalidMessage()
            }
            method = HTTPMethod(string)
        }
        
        // create the request
        return HTTPRequest(
            method: method,
            uri: URI(buffer: results.url),
            version: version,
            headers: headers,
            body: results.body ?? HTTPBody()
        )
    }
}

