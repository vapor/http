import URI
import CHTTP

enum HeaderState {
    case none
    case value(key: HeaderKey, Bytes)
    case key(Bytes)
}

internal final class ParseResults {
    var isComplete: Bool
    var url: Bytes
    var headers: [HeaderKey: String]
    var body: Bytes
    
    var uri: URI?
    var version: Version?
    
    var headerState: HeaderState
    
    init() {
        self.isComplete = false
        self.url = []
        self.headers = [:]
        self.body = []
        self.headerState = .none
    }
    
    static func from(_ parser: UnsafePointer<http_parser>?) -> ParseResults? {
        return parser?
            .pointee
            .data
            .assumingMemoryBound(to: ParseResults.self)
            .pointee
    }
    
    func assertResults() throws -> (
        version: Version,
        uri: URI,
        headers: [HeaderKey: String],
        body: Body
    ) {
        guard let version = self.version else {
            throw ParserError.noVersion
        }
        
        guard let uri = self.uri else {
            throw ParserError.noURI
        }
        
        return (version, uri, headers, .data(body))
    }
}
