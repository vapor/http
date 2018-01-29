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

        let status: HTTPStatus
        switch statusCode {
        case 101: status = .upgrade
        case 200: status = .ok
        case 201: status = .created
        case 202: status = .accepted
        case 204: status = .noContent
        case 205: status = .resetContent
        case 206: status = .partialContent
        case 300: status = .multipleChoices
        case 301: status = .movedPermanently
        case 302: status = .found
        case 303: status = .seeOther
        case 304: status = .notModified
        case 305: status = .useProxy
        case 306: status = .switchProxy
        case 307: status = .temporaryRedirect
        case 308: status = .permanentRedirect
        case 400: status = .badRequest
        case 401: status = .unauthorized
        case 403: status = .forbidden
        case 404: status = .notFound
        case 405: status = .methodNotAllowed
        case 406: status = .notAcceptable
        case 407: status = .proxyAuthenticationRequired
        case 408: status = .requestTimeout
        case 409: status = .conflict
        case 410: status = .gone
        case 411: status = .lengthRequired
        case 412: status = .preconditionFailed
        case 413: status = .requestEntityTooLarge
        case 414: status = .requestURITooLong
        case 415: status = .unsupportedMediaType
        case 416: status = .requestedRangeNotSatisfiable
        case 417: status = .expectationFailed
        case 418: status = .imATeapot
        case 419: status = .authenticationTimeout
        case 420: status = .enhanceYourCalm
        case 421: status = .misdirectedRequest
        case 422: status = .unprocessableEntity
        case 423: status = .locked
        case 424: status = .failedDependency
        case 426: status = .upgradeRequired
        case 428: status = .preconditionRequired
        case 429: status = .tooManyRequests
        case 431: status = .requestHeaderFieldsTooLarge
        case 451: status = .unavailableForLegalReasons
        case 500: status = .internalServerError
        case 501: status = .notImplemented
        case 502: status = .badGateway
        case 503: status = .serviceUnavailable
        case 504: status = .gatewayTimeout
        case 505: status = .httpVersionNotSupported
        case 506: status = .variantAlsoNegotiates
        case 507: status = .insufficientStorage
        case 508: status = .loopDetected
        case 510: status = .notExtended
        case 511: status = .networkAuthenticationRequired
        default: status = HTTPStatus(code: statusCode)
        }

        // create the request
        return HTTPResponse(
            version: version,
            status: status,
            headers: headers,
            body: body
        )
    }
}

