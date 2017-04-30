import Transport
import CHTTP
import URI

public final class ResponseParser<Stream: DuplexStream>: Parser {
    typealias StreamType = Stream
    let stream: Stream
    var parser: http_parser
    var settings: http_parser_settings
    var buffer: Bytes
    
    public init(stream: Stream) {
        self.stream = stream
        self.parser = http_parser()
        self.settings = http_parser_settings()
        http_parser_init(&parser, HTTP_RESPONSE)
        self.buffer = Bytes()
        self.buffer.reserveCapacity(2048)
    }
    
    
    public func parse() throws -> Response {
        http_parser_init(&parser, HTTP_RESPONSE)
        let results = try parseMessage()
        
        let status = Status(statusCode: Int(parser.status_code))
        
        guard let version = results.version else {
            throw ParserError.noVersion
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
