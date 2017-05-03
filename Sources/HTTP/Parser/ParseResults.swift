import URI
import CHTTP

/// Possible header states
enum HeaderState {
    case none
    case value(key: HeaderKey, Bytes)
    case key(Bytes)
}

/// The parse results object helps get around
/// the issue of not being able to capture context
/// with C closures. 
///
/// All C closures must be sent some object that 
/// this parse results object can be retreived from.
/// 
/// See the convenience methods below to see how the
/// object is set and fetched from the C object.
internal final class ParseResults {
    // state
    var headerState: HeaderState
    var isComplete: Bool
    
    // message components
    var version: Version?
    var headers: [HeaderKey: String]
    var body: Bytes

    // url
    var url: Bytes
    
    /// Creates a new results object
    init() {
        self.isComplete = false
        self.url = []
        self.headers = [:]
        self.body = []
        self.headerState = .none
    }
}

// MARK: Convenience

extension ParseResults {
    /// Sets the parse results object on a C parser
    static func set(on parser: inout http_parser) -> ParseResults {
        let results = UnsafeMutablePointer<ParseResults>.allocate(capacity: 1)
        let new = ParseResults()
        results.initialize(to: new)
        parser.data = UnsafeMutableRawPointer(results)
        return new
    }
    
    static func remove(from parser: inout http_parser) {
        if let results = parser.data {
            let pointer = results.assumingMemoryBound(to: ParseResults.self)
            pointer.deinitialize()
            pointer.deallocate(capacity: 1)
        }
    }
    
    /// Fetches the parse results object from the C parser
    static func get(from parser: UnsafePointer<http_parser>?) -> ParseResults? {
        return parser?
            .pointee
            .data
            .assumingMemoryBound(to: ParseResults.self)
            .pointee
    }
}
