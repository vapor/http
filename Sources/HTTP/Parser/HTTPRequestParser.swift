import Bits
import CHTTP
import Async
import Dispatch
import Foundation

/// Parses requests from a readable stream.
public final class HTTPRequestParser: CHTTPParser {
    /// See `InputStream.Input`
    public typealias Input = ByteBuffer

    /// See `OutputStream.Output`
    public typealias Output = HTTPRequest

    /// See CHTTPParser.parserType
    static let parserType: http_parser_type = HTTP_REQUEST

    /// See `CHTTPParser.chttpParserContext`
    var chttp: CHTTPParserContext<HTTPRequest>

    /// See `CHTTPParser.maxHeaderSize`
    public var maxHeaderSize: Int?

    /// Creates a new Request parser.
    public init() {
        self.maxHeaderSize = 100_000
        self.chttp = .init()
        reset()
    }

    /// See `CHTTPParser.makeMessage(from:using:)`
    func makeMessage(from results: CParseResults, using body: HTTPBody) throws -> HTTPRequest {
        // require a version to have been parsed
        guard
            let version = results.version,
            let headers = results.headers,
            let cmethod = results.method
        else {
            throw HTTPError.invalidMessage()
        }
        
        /// switch on the C method type from the parser
        let method: HTTPMethod
        switch cmethod {
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
                let pointer = http_method_str(cmethod),
                let string = String(validatingUTF8: pointer)
            else {
                throw HTTPError.invalidMessage()
            }
            method = HTTPMethod(string)
        }
        
        // parse the uri from the url bytes.
        var uri = URI(buffer: results.url)
        
        // if there is no scheme, use http by default
        if uri.scheme?.isEmpty == true {
            uri.scheme = "http"
        }
        
        // create the request
        return HTTPRequest(
            method: method,
            uri: uri,
            version: version,
            headers: headers,
            body: body
        )
    }
}

