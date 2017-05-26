import Transport
import CHTTP
import URI

/// Parses requests from a readable stream.
public final class RequestParser: CHTTPParser {
    // Internal variables to conform
    // to the C HTTP parser protocol.
    var parser: http_parser
    var settings: http_parser_settings
    var state:  CHTTPParserState

    /// Creates a new Request parser.
    public init() {
        self.parser = http_parser()
        self.settings = http_parser_settings()
        self.state = .ready
        http_parser_init(&parser, HTTP_REQUEST)
        initialize(&settings)
    }

    /// Parses a Request from the stream.
    public func parse(max: Int, from buffer: Bytes) throws -> Request? {
        let results: ParseResults

        switch state {
        case .ready:
            // create a new results object and set
            // a reference to it on the parser
            let newResults = ParseResults.set(on: &parser)
            results = newResults
            state = .parsing
        case .parsing:
            // get the current parse results object
            guard let existingResults = ParseResults.get(from: &parser) else {
                return nil
            }
            results = existingResults
        }

        /// parse the message using the C HTTP parser.
        try executeParser(max: max, from: buffer)

        guard results.isComplete else {
            return nil
        }

        // the results have completed, so we are ready
        // for a new request to come in
        state = .ready
        ParseResults.remove(from: &parser)


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
            let (host, port) = parse(host: hostname)
            uri.hostname = host
            uri.port = port ?? uri.port
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

    func parse(host: String) -> (host: String, port: Port?) {
        let components = host.makeBytes().split(
            separator: .colon,
            maxSplits: 1,
            omittingEmptySubsequences: true
        )
        let host = components.first?.makeString() ?? host
        let port = components.last.flatMap { Int($0.makeString()) }
        return (host, port?.port)
    }
}
