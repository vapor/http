import Transport
import CHTTP
import URI

public final class RequestParser<Stream: DuplexStream>: Parser {
    typealias StreamType = Stream
    let stream: Stream
    var parser: http_parser
    var settings: http_parser_settings
    
    public init(stream: Stream) {
        self.stream = stream
        self.parser = http_parser()
        self.settings = http_parser_settings()
        http_parser_init(&parser, HTTP_REQUEST)
    }
    
    public func parse() throws -> Request {
        let results = try parseMessage()
        
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
            let m = http_method(parser.method)
            let pointer = http_method_str(m)
            let string = String(validatingUTF8: pointer!) ?? ""
            method = .other(method: string)
        }
        
        let (version, uri, headers, body) = try results.assertResults()
        
        let request = Request(
            method: method,
            uri: uri,
            version: version,
            headers: headers,
            body: body
        )
        
        return request
    }
    
}
