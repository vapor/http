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

    /// See `CHTTPParser.chttpParserContext`
    var chttp: CHTTPParserContext

    /// Current downstream accepting parsed messages.
    var downstream: AnyInputStream<HTTPRequest>?

    /// Creates a new Request parser.
    public init() {
        self.chttp = .init(HTTP_REQUEST)
    }

    /// See `CHTTPParser.makeMessage(from:using:)`
    func makeMessage(using body: HTTPBody) throws -> HTTPRequest {
        // require a version to have been parsed
        guard let version = chttp.version, let headers = chttp.headers, let cmethod = chttp.method else {
            throw HTTPError.invalidMessage(source: .capture())
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
                throw HTTPError.invalidMessage(source: .capture())
            }
            method = HTTPMethod(string)
        }
        
        // parse the uri from the url bytes.
        var uri = URI(buffer: chttp.urlData)
        
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

