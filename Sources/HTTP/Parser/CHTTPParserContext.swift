import Async
import Bits
import CHTTP

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

    /// The parsed HTTP version
    var version: HTTPVersion?

    /// The parsed HTTP headers.
    var headers: HTTPHeaders?


    /// Raw headers data
    var headersData: [UInt8]

    /// Parsed indexes into the header data
    var headersIndexes: [HTTPHeaders.Index]


    /// Raw URL data
    var urlData: [UInt8]


    /// Maximum allowed size of the start line + headers data (not including some start line componenets and white space)
    private var maxStartLineAndHeadersSize: Int

    /// Current URL size in start line (excluding other start line components)
    private var currentURLSize: Int

    /// Current size of header data exclusing whitespace
    private var currentHeadersSize: Int


    /// Pointer to the last start location of headers.
    /// If not set, there have been no header start events yet.
    private var headerStart: UnsafePointer<Int8>?

    /// Current header start offset from previous run(s) of the parser
    private var headerStartOffset: Int

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

        self.headersData = []
        self.headersIndexes = []

        self.urlData = []

        self.maxStartLineAndHeadersSize = 100_000
        self.currentURLSize = 0
        self.currentHeadersSize = 0

        self.headerStart = nil
        self.headerStartOffset = 0
        self.bodyStart = nil

        self.parser = http_parser()
        self.settings = http_parser_settings()

        headersIndexes.reserveCapacity(64)
        set(on: &self.parser)
        http_parser_init(&parser, type)
        initialize()
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
    case value(HTTPHeaders.Index)
    case key(startIndex: Int, endIndex: Int)
}


/// Possible body states
enum CHTTPBodyState {
    case none
    case buffer(ByteBuffer)
    case stream(CHTTPBodyStream)
    case readyStream(CHTTPBodyStream, Promise<Void>)
}


/// MARK: Internal

extension CHTTPParserContext {
    /// Parses a generic CHTTP message, filling the
    /// ParseResults object attached to the C praser.
    internal func execute(from buffer: ByteBuffer) throws {
        // call the CHTTP parser
        let parsedCount = http_parser_execute(&parser, &settings, buffer.cPointer, buffer.count)

        // if the parsed count does not equal the bytes passed
        // to the parser, it is signaling an error
        // - 1 to allow room for filtering a possibly final \r\n which I observed the parser does
        guard parsedCount >= buffer.count - 2, parsedCount <= buffer.count else {
            throw HTTPError.invalidMessage()
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

        self.headersData = []
        self.headersIndexes = []

        self.urlData = []

        self.currentURLSize = 0
        self.currentHeadersSize = 0

        self.headerStart = nil
        self.headerStartOffset = 0
        self.bodyStart = nil
    }

    /// Copies raw header data from the buffer into `headersData`
    internal func copyHeaders(from buffer: ByteBuffer) {
        print("copy headers")
        guard startLineComplete else {
            return
        }

        /// start is known header start or buffer start
        let start: UnsafePointer<Int8>
        if let headerStart = self.headerStart {
            start = headerStart
        } else {
            start = buffer.cPointer
        }

        /// end is known body start or buffer end
        let end: UnsafePointer<Int8>
        if let bodyStart = self.bodyStart {
            // end of headers is the body start
            end = bodyStart
        } else {
            // body hasn't started yet
            // get the end of this buffer as *char
            end = buffer.cPointer.advanced(by: buffer.count)
        }

        let headerSize = start.distance(to: end)
        // append the length of the headers in this buffer to the header start offset
        headerStartOffset += start.distance(to: end)
        let buffer = ByteBuffer(start: start.withMemoryRebound(to: Byte.self, capacity: headerSize) { $0 }, count: headerSize)
        headersData.append(contentsOf: buffer)
        headerStart = nil

        if headersComplete {
            print("    set headers")
            headers = HTTPHeaders(storage: headersData, indexes: headersIndexes)
        }
    }

    /// Indicates a close to the HTTP parser.
    internal func close() {
        http_parser_execute(&parser, &settings, nil, 0)
        CHTTPParserContext.remove(from: &self.parser)
    }
}

/// MARK: C-Baton Access

extension CHTTPParserContext {
    /// Sets the parse results object on a C parser
    fileprivate func set(on parser: inout http_parser) {
        let results = UnsafeMutablePointer<CHTTPParserContext>.allocate(capacity: 1)
        results.initialize(to: self)
        parser.data = UnsafeMutableRawPointer(results)
    }

    fileprivate static func remove(from parser: inout http_parser) {
        if let results = parser.data {
            let pointer = results.assumingMemoryBound(to: CHTTPParserContext.self)
            pointer.deinitialize()
            pointer.deallocate(capacity: 1)
        }
    }

    /// Fetches the parse results object from the C parser
    fileprivate static func get(from parser: UnsafePointer<http_parser>?) -> CHTTPParserContext? {
        return parser?
            .pointee
            .data
            .assumingMemoryBound(to: CHTTPParserContext.self)
            .pointee
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
            results.startLineComplete = true

            let start: UnsafePointer<Int8>
            if let existing = results.headerStart {
                start = existing
            } else {
                results.headerStart = chunk
                start = chunk
            }
            print("on_header_field")


            // check current header parsing state
            switch results.headerState {
            case .none:
                let distance = start.distance(to: chunk) + results.headerStartOffset
                // nothing is being parsed, start a new key
                results.headerState = .key(startIndex: distance, endIndex: distance + count)
            case .value(let index):
                let distance = start.distance(to: chunk) + results.headerStartOffset
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
            print("on_header_value")

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
            case .none: fatalError("Illegal header state `none` during `on_header_value`")
            case .value(var index):
                // there was previously a value being parsed.
                // add the new bytes to it.
                index.valueEndIndex += count
                results.headerState = .value(index)
            case .key(let key):
                // there was previously a value being parsed.
                // it is now finished.
                // results.headersData.append(contentsOf: headerSeparator)

                let distance = start.distance(to: chunk) + results.headerStartOffset

                // create a full HTTP headers index
                let index = HTTPHeaders.Index(
                    nameStartIndex: key.startIndex,
                    nameEndIndex: key.endIndex,
                    valueStartIndex: distance,
                    valueEndIndex: distance + count,
                    invalidated: false
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
            print("on_headers_complete")

            // check the current header parsing state
            switch results.headerState {
            case .value(let index):
                // there was previously a value being parsed.
                // it is now finished.
                results.headersIndexes.append(index)

                // let headers = HTTPHeaders(storage: results.headersData, indexes: results.headersIndexes)

                /// FIXME: what was this doing?
                //                if let contentLength = results.contentLength {
                //                    results.body = HTTPBody(size: contentLength, stream: AnyOutputStream(results.bodyStream))
                //                }

                // results.headers = headers
            case .key: fatalError("Unexpected header state .key during on_headers_complete")
            case .none: fatalError("Unexpected header state .none during on_headers_complete")
            }

            // parse version
            let major = Int(parser.pointee.http_major)
            let minor = Int(parser.pointee.http_minor)
            results.version = HTTPVersion(major: major, minor: minor)
            results.method = http_method(parser.pointee.method)
            results.headersComplete = true

            return 0
        }

        // called when chunks of the body have been read
        settings.on_body = { parser, chunk, length in
            guard let results = CHTTPParserContext.get(from: parser), let chunk = chunk else {
                // signal an error
                return 1
            }
            print("on_body")
            results.bodyStart = chunk

            switch results.bodyState {
            case .buffer: fatalError("Unexpected buffer body state during CHTTP.on_body: \(results.bodyState)")
            case .none: results.bodyState = .buffer(chunk.makeByteBuffer(length))
            case .stream: fatalError("Illegal state")
            case .readyStream(let bodyStream, let ready):
                bodyStream.push(chunk.makeByteBuffer(length), ready)
                results.bodyState = .stream(bodyStream) // no longer ready
            }

            return 0
        }

        // called when the message is finished parsing
        settings.on_message_complete = { parser in
            guard let parser = parser, let results = CHTTPParserContext.get(from: parser) else {
                // signal an error
                return 1
            }
            print("on_message_complete")

            // mark the results as complete
            results.messageComplete = true

            return 0
        }
    }
}

// MARK: Utilities

extension UnsafeBufferPointer where Element == Byte {
    fileprivate var cPointer: UnsafePointer<CChar> {
        return baseAddress.unsafelyUnwrapped.withMemoryRebound(to: CChar.self, capacity: count) { $0 }
    }
}

fileprivate let headerSeparator: [UInt8] = [.colon, .space]
fileprivate let lowercasedContentLength = HTTPHeaders.Name.contentLength.lowercased

//fileprivate extension Data {
//    fileprivate var cPointer: UnsafePointer<CChar> {
//        return withUnsafeBytes { $0 }
//    }
//}

fileprivate extension UnsafePointer where Pointee == CChar {
    /// Creates a Bytes array from a C pointer
    fileprivate func makeByteBuffer(_ count: Int) -> ByteBuffer {
        return withMemoryRebound(to: Byte.self, capacity: count) { pointer in
            return ByteBuffer(start: pointer, count: count)
        }
    }

    /// Creates a Bytes array from a C pointer
    fileprivate func makeBuffer(length: Int) -> UnsafeRawBufferPointer {
        let pointer = UnsafeBufferPointer(start: self, count: length)

        guard let base = pointer.baseAddress else {
            return UnsafeRawBufferPointer(start: nil, count: 0)
        }

        return base.withMemoryRebound(to: UInt8.self, capacity: length) { pointer in
            return UnsafeRawBufferPointer(start: pointer, count: length)
        }
    }
}


//extension CHTTPParserContext {
//    fileprivate func parseContentLength(index: HTTPHeaders.Index) {
//        if self.contentLength == nil {
//            let namePointer = UnsafePointer(self.headersData).advanced(by: index.nameStartIndex)
//            let nameLength = index.nameEndIndex - index.nameStartIndex
//            let nameBuffer = ByteBuffer(start: namePointer, count: nameLength)
//
//            if lowercasedContentLength.caseInsensitiveEquals(to: nameBuffer) {
//                let pointer = UnsafePointer(self.headersData).advanced(by: index.valueStartIndex)
//                let length = index.valueEndIndex - index.valueStartIndex
//
//                pointer.withMemoryRebound(to: Int8.self, capacity: length) { pointer in
//                    self.contentLength = numericCast(strtol(pointer, nil, 10))
//                }
//            }
//        }
//    }
//}
//

