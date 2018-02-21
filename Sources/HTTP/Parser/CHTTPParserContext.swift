import Async
import Bits
import CHTTP
import Foundation

/// Maintains the CHTTP parser's internal state.
internal final class CHTTPParserContext {
    /// If true, the start line has been parsed.
    var startLineComplete: Bool

    /// If true, all of the headers have been sent.
    var headersComplete: Bool

    /// If true, the entire message has been parsed.
    var messageComplete: Bool


    /// Parser's message
    var state: CHTTPParserState

    /// The current header parsing state (field, value, etc)
    var headerState: CHTTPHeaderState

    /// The current body parsing state
    var bodyState: CHTTPBodyState


    /// The parsed HTTP method
    var method: http_method?

    /// The parsed HTTP status
    var statusCode: Int?

    /// The parsed HTTP version
    var version: HTTPVersion?

    /// The parsed HTTP headers.
    var headers: HTTPHeaders?


    /// Raw headers data
    var headersData: MutableByteBuffer

    /// Current header start offset from previous run(s) of the parser
    var headersDataSize: Int

    /// Parsed indexes into the header data
    var headersIndexes: [HTTPHeaderIndex]


    /// Raw URL data
    var urlData: [UInt8]


    /// Maximum allowed size of the start line + headers data (not including some start line componenets and white space)
    var maxStartLineAndHeadersSize: Int

    /// Current URL size in start line (excluding other start line components)
    private var currentURLSize: Int

    /// Current size of header data exclusing whitespace
    private var currentHeadersSize: Int


    /// Pointer to the last start location of headers.
    /// If not set, there have been no header start events yet.
    private var headerStart: UnsafePointer<Int8>?

    /// Pointer to the last start location of the body.
    /// If not set, there have been no body start events yet.
    private var bodyStart: UnsafePointer<Int8>?


    /// The CHTTP parser's C struct
    fileprivate var parser: http_parser

    /// The CHTTP parer's C settings
    fileprivate var settings: http_parser_settings

    /// Creates a new `CHTTPParserContext`
    init(_ type: http_parser_type) {
        self.startLineComplete = false
        self.headersComplete = false
        self.messageComplete = false

        self.state = .parsing
        self.headerState = .none
        self.bodyState = .none

        self.method = nil
        self.version = nil
        self.headers = nil

        self.headersData = .allocate(capacity: 64)
        self.headersDataSize = 0
        self.headersIndexes = []

        self.urlData = []

        self.maxStartLineAndHeadersSize = 100_000
        self.currentURLSize = 0
        self.currentHeadersSize = 0

        self.headerStart = nil
        self.bodyStart = nil

        self.parser = http_parser()
        self.settings = http_parser_settings()

        headersIndexes.reserveCapacity(64)
        set(on: &self.parser)
        http_parser_init(&parser, type)
        initialize()
    }

    deinit {
        headersData.deallocate()
    }
}

/// Current parser message state.
enum CHTTPParserState {
    /// Currently parsing an HTTP message, not yet streaming.
    case parsing
    /// We are currently streaming HTTP body to a message.
    /// The future contained is when downstream will be ready for a new HTTP message.
    case streaming(Future<Void>)
    /// Previously streaming an HTTP body, now finished.
    /// The future contained is when downstream will be ready for a new HTTP message.
    case streamingClosed(Future<Void>)
}

/// Possible header states
enum CHTTPHeaderState {
    case none
    case value(HTTPHeaderIndex)
    case key(startIndex: Int, endIndex: Int)
}


/// Possible body states
enum CHTTPBodyState {
    case none
    case buffer(ByteBuffer)
    case data(Data) // used for chunked streams
    case stream(CHTTPBodyStream)
}


/// MARK: Internal

extension CHTTPParserContext {
    /// Parses a generic CHTTP message, filling the
    /// ParseResults object attached to the C praser.
    internal func execute(from buffer: ByteBuffer) throws {
        // call the CHTTP parser
        let parsedCount = buffer.withCPointer { http_parser_execute(&parser, &settings, $0, $1) }

        // if the parsed count does not equal the bytes passed
        // to the parser, it is signaling an error
        // - 1 to allow room for filtering a possibly final \r\n which I observed the parser does
        guard parsedCount >= buffer.count - 2, parsedCount <= buffer.count else {
            throw HTTPError.invalidMessage(source: .capture())
        }
    }

    /// Resets the parser context, preparing it for a new message.
    internal func reset() {
        self.startLineComplete = false
        self.headersComplete = false
        self.messageComplete = false

        self.state = .parsing
        self.headerState = .none
        self.bodyState = .none

        self.method = nil
        self.version = nil
        self.headers = nil

        self.headersDataSize = 0
        self.headersIndexes = []

        self.urlData = []

        self.currentURLSize = 0
        self.currentHeadersSize = 0

        self.headerStart = nil
        self.bodyStart = nil
    }

    /// Copies raw header data from the buffer into `headersData`
    internal func copyHeaders(from buffer: ByteBuffer) {
        guard startLineComplete else {
            /// we should not copy headers until the start line is complete
            /// (there will be no `headerStart` pointer, and buffer start contains non-header data)
            return
        }
        
        /// This vaguely ridiculous wrapper block ensures we don't access memory
        /// improperly - even though that wasn't really a problem anyway. Silly
        /// (yet helpful) memory type binding rules.
        buffer.withCPointer { bufferCPointer, bufferCount in
            /// start is known header start or buffer start
            let start: UnsafePointer<Int8>
            if let headerStart = self.headerStart {
                start = headerStart
                self.headerStart = nil
            } else {
                start = bufferCPointer
            }

            /// end is known body start or buffer end
            let end: UnsafePointer<Int8>
            if let bodyStart = self.bodyStart {
                // end of headers is the body start
                end = bodyStart
            } else {
                // body hasn't started yet
                // get the end of this buffer as *char
                end = bufferCPointer.advanced(by: bufferCount)
            }

            /// current distance from start to end
            let distance = start.distance(to: end)

            let overflow = (headersDataSize + distance) - headersData.count
            if overflow > 0 {
                headersData = headersData.moveToLargerCopy(increasingBy: overflow)
            }

            // append the length of the headers in this buffer to the header start offset
            start.withMemoryRebound(to: Byte.self, capacity: distance) {
                headersData.start.advanced(by: headersDataSize).initialize(from: $0, count: distance)
                headersDataSize += distance
            }
        }
        
        /// if this buffer copy is happening after headers complete indication,
        /// set the headers struct for later retreival
        if headersComplete {
            let storage = HTTPHeaderStorage(
                copying: ByteBuffer(start: headersData.start, count: headersDataSize),
                with: headersIndexes
            )
            headers = HTTPHeaders(storage: storage)
        }
    }

    /// Indicates a close to the HTTP parser.
    internal func close() {
        http_parser_execute(&parser, &settings, nil, 0)
        CHTTPParserContext.remove(from: &self.parser)
    }
}

/// Private methods

extension CHTTPParserContext {
    /// Returns true if adding the supplied length to the current
    /// size is still within maximum size boundaries.
    fileprivate func isUnderMaxSize() -> Bool {
        guard (currentURLSize + currentHeadersSize) <= maxStartLineAndHeadersSize else {
            return false
        }
        return true
    }

    /// Initializes the http parser settings with appropriate callbacks.
    fileprivate func initialize() {
        // called when chunks of the url have been read
        settings.on_url = { parser, chunk, count in
            guard let results = CHTTPParserContext.get(from: parser), let chunk = chunk else {
                // signal an error
                return 1
            }
            DEBUG("on_url")

            // increase url count
            results.currentURLSize += count

            // verify we are within max size limits
            guard results.isUnderMaxSize() else {
                // signal an error
                return 1
            }

            /// FIXME: optimize url append
            // append the url bytes to the results
            chunk.withMemoryRebound(to: Byte.self, capacity: count) { chunkPointer in
                let buffer = ByteBuffer(start: chunkPointer, count: count)
                results.urlData.append(contentsOf: buffer)
            }

            // return success
            return 0
        }

        // called when chunks of a header field have been read
        settings.on_header_field = { parser, chunk, count in
            guard let results = CHTTPParserContext.get(from: parser), let chunk = chunk else {
                // signal an error
                return 1
            }
            DEBUG("on_header_field")

            /// Header fields are the first indication that the start-line has completed.
            results.startLineComplete = true

            /// Get headerStart pointer. If nil, then there has not
            /// been a header event yet.
            let start: UnsafePointer<Int8>
            if let existing = results.headerStart {
                start = existing
            } else {
                results.headerStart = chunk
                start = chunk
            }

            // check current header parsing state
            switch results.headerState {
            case .none:
                let distance = start.distance(to: chunk) + results.headersDataSize
                // nothing is being parsed, start a new key
                results.headerState = .key(startIndex: distance, endIndex: distance + count)
            case .value(let index):
                let distance = start.distance(to: chunk) + results.headersDataSize
                // there was previously a value being parsed.
                // it is now finished.
                results.headersIndexes.append(index)
                // start a new key
                results.headerState = .key(startIndex: distance, endIndex: distance + count)
            case .key(let start, let end):
                // there is a key currently being parsed, extend the count index
                results.headerState = .key(startIndex: start, endIndex: end + count)
            }

            // verify total size has not exceeded max
            results.currentHeadersSize += count

            // verify we are within max size limits
            guard results.isUnderMaxSize() else {
                return 1
            }

            return 0
        }

        // called when chunks of a header value have been read
        settings.on_header_value = { parser, chunk, count in
            guard let results = CHTTPParserContext.get(from: parser), let chunk = chunk else {
                // signal an error
                return 1
            }
            DEBUG("on_header_value")

            /// Get headerStart pointer. If nil, then there has not
            /// been a header event yet.
            let start: UnsafePointer<Int8>
            if let existing = results.headerStart {
                start = existing
            } else {
                results.headerStart = chunk
                start = chunk
            }

            // increase headers size
            results.currentHeadersSize += count

            // verify we are within max size limits
            guard results.isUnderMaxSize() else {
                return 1
            }

            // check the current header parsing state
            switch results.headerState {
            case .none: ERROR("Unexpected headerState (.key) during chttp.on_header_value")
            case .value(var index):
                // there was previously a value being parsed.
                // add the new bytes to it.
                index.valueEndIndex += count
                results.headerState = .value(index)
            case .key(let key):
                let distance = start.distance(to: chunk) + results.headersDataSize

                // create a full HTTP headers index
                let index = HTTPHeaderIndex(
                    nameStartIndex: key.startIndex,
                    nameEndIndex: key.endIndex,
                    valueStartIndex: distance,
                    valueEndIndex: distance + count
                )
                results.headerState = .value(index)
            }
            return 0
        }

        // called when header parsing has completed
        settings.on_headers_complete = { parser in
            guard let parser = parser, let results = CHTTPParserContext.get(from: parser) else {
                // signal an error
                return 1
            }
            DEBUG("on_headers_complete")

            // check the current header parsing state
            switch results.headerState {
            case .value(let index): results.headersIndexes.append(index)
            case .key: ERROR("Unexpected headerState (.key) during chttp.on_headers_complete")
            case .none: ERROR("Unexpected headerState (.none) during chttp.on_headers_complete")
            }

            /// if headers are complete, so is the start line.
            /// parse all start-line information now
            let major = Int(parser.pointee.http_major)
            let minor = Int(parser.pointee.http_minor)
            results.version = HTTPVersion(major: major, minor: minor)
            results.method = http_method(parser.pointee.method)
            results.statusCode = Int(parser.pointee.status_code)
            results.headersComplete = true

            return 0
        }

        // called when chunks of the body have been read
        settings.on_body = { parser, chunk, length in
            guard let results = CHTTPParserContext.get(from: parser), let chunk = chunk else {
                // signal an error
                return 1
            }
            DEBUG("on_body: \(results.bodyState)")
            results.bodyStart = chunk

            switch results.bodyState {
            case .buffer(let buffer):
                // multiple buffers incoming, we must copy into data
                var data = Data(buffer)
                data.append(chunk.makeByteBuffer(length))
                results.bodyState = .data(data)
            case .data(var data):
                data.append(chunk.makeByteBuffer(length))
                results.bodyState = .data(data)
            case .none: results.bodyState = .buffer(chunk.makeByteBuffer(length))
            case .stream(let stream): stream.push(chunk.makeByteBuffer(length))
            }

            return 0
        }

        // called when the message is finished parsing
        settings.on_message_complete = { parser in
            guard let parser = parser, let results = CHTTPParserContext.get(from: parser) else {
                // signal an error
                return 1
            }
            DEBUG("on_message_complete")

            // mark the results as complete
            results.messageComplete = true

            return 0
        }
    }
}



/// MARK: C Baton Access

extension CHTTPParserContext {
    /// Sets C pointer for this context on the http_parser's data.
    /// Use `CHTTPParserContext.get(from:)` to fetch back.
    fileprivate func set(on parser: inout http_parser) {
        parser.data = Unmanaged<CHTTPParserContext>.passUnretained(self).toOpaque()
    }

    /// Removes C pointer from http_parser data
    fileprivate static func remove(from parser: inout http_parser) {
        parser.data = nil // we didn't take a retain on self, so nothing to deallocate
    }

    /// Fetches the parse results object from the C http_parser data
    fileprivate static func get(from parser: UnsafePointer<http_parser>?) -> CHTTPParserContext? {
        return parser.flatMap {
            Unmanaged<CHTTPParserContext>.fromOpaque($0.pointee.data).takeUnretainedValue()
        }
    }
}

// MARK: Utilities

extension UnsafeBufferPointer where Element == Byte /* ByteBuffer */ {
    /// Creates a C pointer from a Byte Buffer and runs the closure on it.
    /// The closure is passed the CChar pointer and the buffer size.
    fileprivate func withCPointer<Result>(work: (_ pointer: UnsafePointer<CChar>, _ count: Int) throws -> Result) rethrows -> Result {
        return try baseAddress.unsafelyUnwrapped.withMemoryRebound(to: CChar.self, capacity: count) {
            return try work($0, count)
        }
    }
}

fileprivate extension UnsafePointer where Pointee == CChar {
    /// Creates a Bytes Buffer from a C pointer.
    fileprivate func makeByteBuffer(_ count: Int) -> ByteBuffer {
        return withMemoryRebound(to: Byte.self, capacity: count) { pointer in
            return ByteBuffer(start: pointer, count: count)
        }
    }
}
