import CHTTP
import Dispatch
import Foundation

/// The parse results object helps get around
/// the issue of not being able to capture context
/// with C closures.
///
/// All C closures must be sent some object that
/// this parse results object can be retreived from.
///
/// See the convenience methods below to see how the
/// object is set and fetched from the C object.
internal final class CParseResults {
    // state
    var headerState: HeaderState
    var isComplete: Bool

    // message components
    var version: HTTPVersion?
    var headersIndexes: [HTTPHeaders.Index]
    var headersData = [UInt8]()
    
    var currentSize: Int = 0
    var maxMessageSize: Int
    var maxHeaderSize: Int
    var maxBodySize: Int
    
    var headers: HTTPHeaders?
    var bodyData = Data()
    
    var body: HTTPBody {
        return HTTPBody(bodyData)
    }
    
    var url = [UInt8]()
    
    /// Creates a new results object
    init<Parser: CHTTPParser>(parser: Parser) {
        self.isComplete = false
        self.headersIndexes = []
        headersData.reserveCapacity(4096)
        headersIndexes.reserveCapacity(64)
        url.reserveCapacity(128)
        self.maxMessageSize = parser.maxMessageSize
        self.maxHeaderSize = parser.maxHeaderSize
        self.maxBodySize = parser.maxBodySize
        
        self.headerState = .none
    }
}

// MARK: Convenience

extension CParseResults {
    /// Sets the parse results object on a C parser
    static func set<Parser: CHTTPParser>(on parser: inout http_parser, swiftParser: Parser) -> CParseResults {
        let results = UnsafeMutablePointer<CParseResults>.allocate(capacity: 1)
        let new = CParseResults(parser: swiftParser)
        results.initialize(to: new)
        parser.data = UnsafeMutableRawPointer(results)
        return new
    }

    static func remove(from parser: inout http_parser) {
        if let results = parser.data {
            let pointer = results.assumingMemoryBound(to: CParseResults.self)
            pointer.deinitialize()
            pointer.deallocate(capacity: 1)
        }
    }

    /// Fetches the parse results object from the C parser
    static func get(from parser: UnsafePointer<http_parser>?) -> CParseResults? {
        return parser?
            .pointee
            .data
            .assumingMemoryBound(to: CParseResults.self)
            .pointee
    }
}
