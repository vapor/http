import Async
import Bits
import CHTTP
import Dispatch
import Foundation

/// Internal CHTTP parser protocol
internal protocol CHTTPParser: HTTPParser where Input == ByteBuffer {
    /// This parser's type (request or response)
    static var parserType: http_parser_type { get }

    /// If set, header data exceeding the specified size will result in an error.
    var maxHeaderSize: Int? { get set }

    /// Holds the CHTTP parser's internal state.
    var chttp: CHTTPParserContext<Output> { get set }

    /// Converts the CHTTP parser results and body to HTTP message.
    func makeMessage(from results: CParseResults, using body: HTTPBody) throws -> Output
}

/// Possible header states
enum CHTTPHeaderState {
    case none
    case value(HTTPHeaders.Index)
    case key(startIndex: Int, endIndex: Int)
}

enum CHTTPMessageState<Message> {
    case parsing
    case streaming(Message, Future<Void>)
    case waiting(Future<Void>)
}

/// Possible body states
enum CHTTPBodyState {
    case none
    case buffer(ByteBuffer)
    case stream(CHTTPBodyStream)
    case readyStream(CHTTPBodyStream, Promise<Void>)
}

/// Maintains the CHTTP parser's internal state.
struct CHTTPParserContext<Message> {
    /// Whether the parser is currently parsing or hasn't started yet
    var isParsing: Bool

    /// Parser's message
    var messageState: CHTTPMessageState<Message>

    /// The CHTTP parser's C struct
    var parser: http_parser

    /// The CHTTP parer's C settings
    var settings: http_parser_settings

    /// Current downstream.
    var downstream: AnyInputStream<Message>?

    /// Creates a new `CHTTPParserContext`
    init() {
        self.parser = http_parser()
        self.settings = http_parser_settings()
        self.isParsing = false
        self.messageState = .parsing
    }
}

/// MARK: CHTTPParser OutputStream

extension CHTTPParser {
    /// See `OutputStream.output(to:)`
    public func output<S>(to inputStream: S) where S: Async.InputStream, Self.Output == S.Input {
        chttp.downstream = .init(inputStream)
    }
}

/// MARK: CHTTPParser InputStream

extension CHTTPParser {
    /// See `InputStream.input(_:)`
    public func input(_ event: InputEvent<ByteBuffer>) {
        switch event {
        case .close:
            chttp.close()
            chttp.downstream!.close()
        case .error(let error): chttp.downstream!.error(error)
        case .next(let input, let ready): try! handleNext(input, ready)
        }
    }

    /// See `InputEvent.next`
    private func handleNext(_ buffer: ByteBuffer, _ ready: Promise<Void>) throws {
        guard let results = chttp.getResults() else {
            throw HTTPError(identifier: "getResults", reason: "An internal HTTP Parser state became invalid")
        }

        switch chttp.messageState {
        case .parsing:
            /// Parse the message using the CHTTP parser.
            try chttp.execute(from: buffer)

            /// Check if we have received all of the messages headers
            if results.headersComplete {
                /// Either streaming or static will be decided
                let body: HTTPBody

                /// The message is ready to move downstream, check to see
                /// if we already have the HTTPBody in its entirety
                if results.messageComplete {
                    switch results.bodyState {
                    case .buffer(let buffer): body = HTTPBody(Data(buffer))
                    case .none: body = HTTPBody()
                    case .stream: fatalError("Illegal state")
                    case .readyStream: fatalError("Illegal state")
                    }

                    let message = try makeMessage(from: results, using: body)
                    chttp.downstream!.next(message, ready)

                    // the results have completed, so we are ready
                    // for a new request to come in
                    chttp.isParsing = false
                    CParseResults.remove(from: &chttp.parser)
                } else {
                    // Convert body to a stream
                    let stream = CHTTPBodyStream()
                    switch results.bodyState {
                    case .buffer(let buffer): stream.push(buffer, ready)
                    case .none: stream.push(ByteBuffer(start: nil, count: 0), ready)
                    case .stream: fatalError("Illegal state")
                    case .readyStream: fatalError("Illegal state")
                    }
                    results.bodyState = .stream(stream)
                    body = HTTPBody(size: results.contentLength, stream: .init(stream))
                    let message = try makeMessage(from: results, using: body)
                    let future = chttp.downstream!.next(message)
                    chttp.messageState = .streaming(message, future)
                }
            } else {
                /// Headers not complete, request more input
                ready.complete()
            }
        case .streaming(_, let future):
            let stream: CHTTPBodyStream

            /// Close the body stream now
            switch results.bodyState {
            case .none: fatalError("Illegal state")
            case .buffer: fatalError("Illegal state")
            case .readyStream: fatalError("Illegal state")
            case .stream(let s):
                stream = s
                // replace body state w/ new ready
                results.bodyState = .readyStream(s, ready)
            }

            /// Parse the message using the CHTTP parser.
            try chttp.execute(from: buffer)

            if results.messageComplete {
                /// Close the body stream now
                stream.close()
                chttp.messageState = .waiting(future)
            }
        case .waiting(let future):
            // the results have completed, so we are ready
            // for a new request to come in
            chttp.isParsing = false
            CParseResults.remove(from: &chttp.parser)
            chttp.messageState = .parsing
            future.do {
                try! self.handleNext(buffer, ready)
            }.catch { error in
                fatalError("\(error)")
            }
        }
    }

    /// Resets the parser
    public func reset() {
        chttp.reset(Self.parserType)
    }
}

/// MARK: CHTTP integration

extension CHTTPParserContext {
    /// Parses a generic CHTTP message, filling the
    /// ParseResults object attached to the C praser.
    internal mutating func execute(from buffer: ByteBuffer) throws {
        // call the CHTTP parser
        let parsedCount = http_parser_execute(&parser, &settings, buffer.cPointer, buffer.count)

        // if the parsed count does not equal the bytes passed
        // to the parser, it is signaling an error
        // - 1 to allow room for filtering a possibly final \r\n which I observed the parser does
        guard parsedCount >= buffer.count - 2, parsedCount <= buffer.count else {
            throw HTTPError.invalidMessage()
        }
    }

    /// Resets the parser
    internal mutating func reset(_ type: http_parser_type) {
        http_parser_init(&parser, type)
        initialize()
    }
}

extension CParseResults {
    func parseContentLength(index: HTTPHeaders.Index) {
        if self.contentLength == nil {
            let namePointer = UnsafePointer(self.headersData).advanced(by: index.nameStartIndex)
            let nameLength = index.nameEndIndex - index.nameStartIndex
            let nameBuffer = ByteBuffer(start: namePointer, count: nameLength)
            
            if lowercasedContentLength.caseInsensitiveEquals(to: nameBuffer) {
                let pointer = UnsafePointer(self.headersData).advanced(by: index.valueStartIndex)
                let length = index.valueEndIndex - index.valueStartIndex
                
                pointer.withMemoryRebound(to: Int8.self, capacity: length) { pointer in
                    self.contentLength = numericCast(strtol(pointer, nil, 10))
                }
            }
        }
    }
}

extension CHTTPParserContext {
    /// Fetches `CParseResults` from the praser.
    mutating func getResults() -> CParseResults? {
        let results: CParseResults
        if isParsing {
            // get the current parse results object
            guard let existingResults = CParseResults.get(from: &parser) else {
                return nil
            }
            results = existingResults
        } else {
            // create a new results object and set
            // a reference to it on the parser
            let newResults = CParseResults.set(on: &parser)
            results = newResults
            isParsing = true
        }
        return results
    }

    /// Indicates a close to the HTTP parser.
    mutating func close() {
        http_parser_execute(&parser, &settings, nil, 0)
    }
    
    /// Initializes the http parser settings with appropriate callbacks.
    mutating func initialize() {
        // called when chunks of the url have been read
        settings.on_url = { parser, chunkPointer, length in
            print("chttp: on_url '\(String(data: Data(chunkPointer!.makeBuffer(length: length)), encoding: .ascii)!)' (\(length)) ")
            guard
                let results = CParseResults.get(from: parser),
                let chunkPointer = chunkPointer
            else {
                // signal an error
                return 1
            }
            
            guard results.addSize(length) else {
                return 1
            }

            // append the url bytes to the results
            chunkPointer.withMemoryRebound(to: UInt8.self, capacity: length) { chunkPointer in
                results.url.append(contentsOf: ByteBuffer(start: chunkPointer, count: length))
            }
            
            return 0
        }

        // called when chunks of a header field have been read
        settings.on_header_field = { parser, chunkPointer, length in
            print("chttp: on_header_field '\(String(data: Data(chunkPointer!.makeBuffer(length: length)), encoding: .ascii)!)' (\(length)) ")
            guard
                let results = CParseResults.get(from: parser),
                let chunkPointer = chunkPointer
            else {
                // signal an error
                return 1
            }
            
            guard results.addSize(length + 4) else { // + ": \r\n"
                return 1
            }
            
            // check current header parsing state
            switch results.headerState {
            case .none:
                // nothing is being parsed, start a new key
                results.headerState = .key(startIndex: results.headersData.count, endIndex: results.headersData.count + length)
            case .value(let index):
                // there was previously a value being parsed.
                // it is now finished.
                
                results.headersIndexes.append(index)
                
                results.headersData.append(.carriageReturn)
                results.headersData.append(.newLine)
                
                results.parseContentLength(index: index)
                
                // start a new key
                results.headerState = .key(startIndex: results.headersData.count, endIndex: results.headersData.count + length)
            case .key(let start, let end):
                // there is a key currently being parsed.
                results.headerState = .key(startIndex: start, endIndex: end + length)
            }
            
            chunkPointer.withMemoryRebound(to: UInt8.self, capacity: length) { chunkPointer in
                results.headersData.append(contentsOf: ByteBuffer(start: chunkPointer, count: length))
            }

            return 0
        }

        // called when chunks of a header value have been read
        settings.on_header_value = { parser, chunkPointer, length in
            print("chttp: on_header_value '\(String(data: Data(chunkPointer!.makeBuffer(length: length)), encoding: .ascii)!)' (\(length)) ")
            guard
                let results = CParseResults.get(from: parser),
                let chunkPointer = chunkPointer
            else {
                // signal an error
                return 1
            }
            
            guard results.addSize(length + 2) else { // + "\r\n"
                return 1
            }

            // check the current header parsing state
            switch results.headerState {
            case .none:
                // nothing has been parsed, so this
                // value is useless.
                // (this should never be reached)
                results.headerState = .none
            case .value(var index):
                // there was previously a value being parsed.
                // add the new bytes to it.
                index.nameEndIndex += length
                results.headerState = .value(index)
            case .key(let key):
                // there was previously a key being parsed.
                // it is now finished.
                results.headersData.append(contentsOf: headerSeparator)
                
                // Set a dummy hashvalue
                let index = HTTPHeaders.Index(
                    nameStartIndex: key.startIndex,
                    nameEndIndex: key.endIndex,
                    valueStartIndex: results.headersData.count,
                    valueEndIndex: results.headersData.count + length,
                    invalidated: false
                )
                
                results.headerState = .value(index)
            }
            
            chunkPointer.withMemoryRebound(to: UInt8.self, capacity: length) { chunkPointer in
                results.headersData.append(contentsOf: ByteBuffer(start: chunkPointer, count: length))
            }

            return 0
        }

        // called when header parsing has completed
        settings.on_headers_complete = { parser in
            print("chttp: on_headers_complete")
            guard let parser = parser, let results = CParseResults.get(from: parser) else {
                // signal an error
                return 1
            }

            // check the current header parsing state
            switch results.headerState {
            case .value(let index):
                // there was previously a value being parsed.
                // it should be added to the headers dict.
                
                results.headersIndexes.append(index)
                results.headersData.append(.carriageReturn)
                results.headersData.append(.newLine)
                
                results.parseContentLength(index: index)
                
                let headers = HTTPHeaders(storage: results.headersData, indexes: results.headersIndexes)

                /// FIXME: what was this doing?
//                if let contentLength = results.contentLength {
//                    results.body = HTTPBody(size: contentLength, stream: AnyOutputStream(results.bodyStream))
//                }

                results.headers = headers
            default:
                // no other cases need to be handled.
                break
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
            print("chttp: on_body '\(String(data: Data(chunk!.makeBuffer(length: length)), encoding: .ascii)!)' (\(length)) ")
            guard let results = CParseResults.get(from: parser), let chunk = chunk else {
                // signal an error
                return 1
            }

            switch results.bodyState {
            case .buffer: fatalError("Unexpected buffer body state during CHTTP.on_body: \(results.bodyState)")
            case .none: results.bodyState = .buffer(chunk.makeByteBuffer(length))
            case .stream: fatalError("Illegal state")
            case .readyStream(let bodyStream, let ready):
                bodyStream.push(chunk.makeByteBuffer(length), ready)
                results.bodyState = .stream(bodyStream) // no longer ready
            }

            return 0
//            return chunk.withMemoryRebound(to: UInt8.self, capacity: length) { pointer -> Int32 in
//                results.bodyStream.push(ByteBuffer(start: pointer, count: length))
//
//                return 0
//            }
        }

        // called when the message is finished parsing
        settings.on_message_complete = { parser in
            print("chttp: on_message_complete")
            guard let parser = parser, let results = CParseResults.get(from: parser) else {
                // signal an error
                return 1
            }
            
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

fileprivate extension Data {
    fileprivate var cPointer: UnsafePointer<CChar> {
        return withUnsafeBytes { $0 }
    }
}

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


