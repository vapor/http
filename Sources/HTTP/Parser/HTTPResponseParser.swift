 import CHTTP
import Async
import Bits
import Foundation

/// Parses requests from a readable stream.
 public final class HTTPResponseParser: CHTTPParser {
    public typealias Input = ByteBuffer
    public typealias Output = Message
    
    /// See HTTPParser.Message
    public typealias Message = HTTPResponse

    /// See CHTTPParser.parserType
    static let parserType: http_parser_type = HTTP_RESPONSE

    public var message: HTTPResponse?
    
    // Internal variables to conform
    // to the C HTTP parser protocol.
    var parser: http_parser
    var settings: http_parser_settings
    var state:  CHTTPParserState
    var upstream: ConnectionContext?
    var downstream: AnyInputStream<HTTPResponse>?
    var downstreamDemand: UInt
    public var messageBodyCompleted: Bool

    /// The maxiumum possible body size
    /// larger sizes will result in an error
    public var maxMessageSize: Int?
    public var maxHeaderSize: Int?
    public var maxBodySize: Int?
    
    /// Creates a new Request parser.
    public init(maxSize: Int) {
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

    /// See CHTTPParser.makeMessage
    func makeMessage(from results: CParseResults) throws -> HTTPResponse {
        // require a version to have been parsed
        guard
            let version = results.version,
            let headers = results.headers
        else {
            throw HTTPError.invalidMessage()
        }
        
        /// get response status
        let status = HTTPStatus(code: Int(parser.status_code))
        
        // create the request
        return HTTPResponse(
            version: version,
            status: status,
            headers: headers,
            body: results.body
        )
    }
}
