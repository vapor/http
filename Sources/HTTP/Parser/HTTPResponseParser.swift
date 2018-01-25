 import CHTTP
import Async
import Bits
import Foundation

/// Parses requests from a readable stream.
 public final class HTTPResponseParser: CHTTPParser {
    /// See `InputStream.Input`
    public typealias Input = ByteBuffer

    /// See `OutputStream.Output`
    public typealias Output = HTTPResponse

    /// See `CHTTPParser.chttpParserContext`
    var chttp: CHTTPParserContext

    /// Current downstream accepting parsed messages.
    var downstream: AnyInputStream<HTTPResponse>?

    /// Creates a new Request parser.
    public init() {
        self.chttp = .init(HTTP_RESPONSE)
    }

    /// See CHTTPParser.makeMessage
    func makeMessage(using body: HTTPBody) throws -> HTTPResponse {
        // require a version to have been parsed
        guard let version = chttp.version, let headers = chttp.headers, let statusCode = chttp.statusCode else {
            throw HTTPError.invalidMessage()
        }

        // create the request
        return HTTPResponse(
            version: version,
            status: HTTPStatus(code: statusCode),
            headers: headers,
            body: body
        )
    }
}

