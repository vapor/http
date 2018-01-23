import Async
import Bits
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
    /// If true, all of the headers have been sent.
    var headersComplete: Bool

    /// If true, the entire message has been parsed.
    var messageComplete: Bool

    /// The current header parsing state (field, value, etc)
    var headerState: CHTTPHeaderState

    /// The current body parsing state
    var bodyState: CHTTPBodyState

    /// The HTTP method (only set for requests)
    var method: http_method?

    // The HTTP version
    var version: HTTPVersion?

    var headersIndexes: [HTTPHeaders.Index]
    var headersData = [UInt8]()
    var currentSize: Int = 0
    var maxHeaderSize: Int?
    var contentLength: Int?
    var headers: HTTPHeaders?
    var url = [UInt8]()
    
    /// Creates a new results object
    init() {
        self.headersComplete = false
        self.messageComplete = false
        self.headersIndexes = []
        headersData.reserveCapacity(4096)
        headersIndexes.reserveCapacity(64)
        url.reserveCapacity(128)
        self.maxHeaderSize = 100_000
        self.headerState = .none
        self.bodyState = .none
    }
    
    func addSize(_ n: Int) -> Bool {
        if let maxHeaderSize = maxHeaderSize {
            guard currentSize + n <= maxHeaderSize else {
                return false
            }
            
            self.currentSize += n
        }
        
        return true
    }
}

// MARK: Convenience

extension CParseResults {
    /// Sets the parse results object on a C parser
    static func set(on parser: inout http_parser) -> CParseResults {
        let results = UnsafeMutablePointer<CParseResults>.allocate(capacity: 1)
        let new = CParseResults()
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
