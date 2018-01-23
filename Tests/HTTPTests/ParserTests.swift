import Async
import Bits
import Dispatch
import HTTP
import XCTest


extension String {
    var buffer: ByteBuffer {
        return self.data(using: .utf8)!.withByteBuffer { $0 }
    }
}
public final class ProtocolTester: Async.OutputStream {
    /// See `OutputStream.Output`
    public typealias Output = ByteBuffer

    /// Stream being tested
    public var downstream: AnyInputStream<ByteBuffer>?

    /// See `OutputStream.output`
    public func output<S>(to inputStream: S) where S: Async.InputStream, ProtocolTester.Output == S.Input {
        downstream = .init(inputStream)
    }

    private var reset: () -> ()
    private var fail: (String, StaticString, UInt) -> ()
    private var checks: [ProtocolTesterCheck]

    private struct ProtocolTesterCheck {
        var minOffset: Int?
        var maxOffset: Int?
        var file: StaticString
        var line: UInt
        var checks: () throws -> ()
    }

    public init(onFail: @escaping (String, StaticString, UInt) -> (), reset: @escaping () -> ()) {
        self.reset = reset
        self.fail = onFail
        checks = []
    }

    public func assert(before offset: Int, file: StaticString = #file, line: UInt = #line, callback: @escaping () throws -> ()) {
        let check = ProtocolTesterCheck(minOffset: nil, maxOffset: offset, file: file, line: line, checks: callback)
        checks.append(check)
    }

    public func assert(after offset: Int, file: StaticString = #file, line: UInt = #line, callback: @escaping () throws -> ()) {
        let check = ProtocolTesterCheck(minOffset: offset, maxOffset: nil, file: file, line: line, checks: callback)
        checks.append(check)
    }

    /// Runs the protocol tester w/ the supplied input
    public func run(_ string: String) -> Future<Void> {
        Swift.assert(downstream != nil, "ProtocolTester must be connected before running")
        let buffer = string.buffer
        return runMax(buffer, max: buffer.count)
    }

    private func runMax(_ buffer: ByteBuffer, max: Int) -> Future<Void> {
        if max > 0 {
            let maxSizedChunksCount = buffer.count / max
            let lastChunkSize = buffer.count % max

            var chunks: [ByteBuffer] = []

            for i in 0..<maxSizedChunksCount {
                let maxSizedChunk = ByteBuffer(start: buffer.baseAddress?.advanced(by: i * max), count: max)
                chunks.insert(maxSizedChunk, at: 0)
            }

            if lastChunkSize > 0 {
                let lastChunk = ByteBuffer(start: buffer.baseAddress?.advanced(by: buffer.count - lastChunkSize), count: lastChunkSize)
                chunks.insert(lastChunk, at: 0)
            }

            reset()
            return runChunks(chunks, currentOffset: 0, original: chunks).flatMap(to: Void.self) {
                return self.runMax(buffer, max: max - 1)
            }
        } else {
            downstream?.close()
            return .done
        }
    }

    private func runChunks(_ chunks: [ByteBuffer], currentOffset: Int, original: [ByteBuffer]) -> Future<Void> {
        var chunks = chunks
        if let chunk = chunks.popLast() {
            runChecks(offset: currentOffset, chunks: original)
            return downstream!.next(chunk).flatMap(to: Void.self) { _ in
                return self.runChunks(chunks, currentOffset: currentOffset + chunk.count, original: original)
            }
        } else {
            runChecks(offset: currentOffset, chunks: original)
            return .done
        }
    }

    private func runChecks(offset: Int, chunks: [ByteBuffer]) {
        for check in checks {
            var shouldRun = false
            if let min = check.minOffset, offset >= min {
                shouldRun = true
            }
            if let max = check.maxOffset, offset < max {
                shouldRun = true
            }
            if shouldRun {
                do {
                    try check.checks()
                } catch {
                    var message = "Protocol test failed: \(error)"
                    let data = chunks.reversed().map { "[" + ProtocolTester.dataDebug(for: $0) + "]" }.joined(separator: " ")
                    let text = chunks.reversed().map { "[" + ProtocolTester.textDebug(for: $0) + "]" }.joined(separator: " ")
                    message += "\nData: \(data)"
                    message += "\nText: \(text)"
                    self.fail(message, check.file, check.line)
                }
            }
        }
    }

    static func textDebug(for buffer: ByteBuffer) -> String {
        let string = String(bytes: buffer, encoding: .ascii) ?? "n/a"
        return string
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// See `CustomStringConvertible.description`
    static func dataDebug(for buffer: ByteBuffer) -> String {
        var string = "0x"
        for i in 0..<buffer.count {
            let byte = buffer[i]
            let upper = Int(byte >> 4)
            let lower = Int(byte & 0b00001111)
            string.append(hexMap[upper])
            string.append(hexMap[lower])
        }
        return string
    }

    static let hexMap = ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "A", "B", "C", "D", "E", "F"]
}
extension String: Error {}

class ParserTests : XCTestCase {


    func testParserEdgeCasesOld() throws {
        // captured variables to check
        var request: HTTPRequest?
        var content: String?
        var isClosed = false

        // configure parser stream
        let socket = PushStream(ByteBuffer.self)
        socket.stream(to: HTTPRequestParser()).drain { message in
            request = message
            message.body.makeData(max: 100).do { data in
                content = String(data: data, encoding: .ascii)
            }.catch { error in
                XCTFail("body error: \(error)")
            }
        }.catch { error in
            XCTFail("parser error: \(error)")
        }.finally {
            isClosed = true
        }

        // pre-step
        XCTAssertNil(request)
        XCTAssertNil(content)
        XCTAssertFalse(isClosed)

        // (1) FIRST ---
        socket.push("GET /hello HTTP/1.1\r\nContent-Type: ".buffer)
        XCTAssertNil(request)
        XCTAssertNil(content)
        XCTAssertFalse(isClosed)

        // (2) SECOND ---
        socket.push("text/plain\r\nContent-Length: 5\r\n\r\nwo".buffer)
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.uri.path, "/hello")
        XCTAssertEqual(request?.method, .get)
        XCTAssertNil(content)
        XCTAssertFalse(isClosed)

        // (3) THIRD ---
        socket.push("rl".buffer)
        XCTAssertNil(content)
        XCTAssertFalse(isClosed)

        // (4) FOURTH ---
        socket.push("d".buffer)
        XCTAssertEqual(content, "world")
        XCTAssertFalse(isClosed)

        // (c) CLOSE ---
        socket.close()
        XCTAssertTrue(isClosed)
    }


    func testParserEdgeCases() throws {
        // captured variables to check
        var request: HTTPRequest?
        var content: String?
        var isClosed = false

        // creates a protocol tester
        let tester = ProtocolTester(onFail: XCTFail) {
            request = nil
            content = nil
            isClosed = false
        }

        tester.assert(before: 68) {
            guard request == nil else {
                throw "request was not nil"
            }
        }

        tester.assert(after: 68) {
            guard request != nil else {
                throw "request was nil"
            }
        }

        tester.assert(after: 73) {
            guard let string = content else {
                throw "content was nil"
            }

            guard string == "world" else {
                throw "incorrect string"
            }
        }

        // configure parser stream
        tester.stream(to: HTTPRequestParser()).drain { message in
            request = message
            message.body.makeData(max: 100).do { data in
                content = String(data: data, encoding: .ascii)
            }.catch { error in
                XCTFail("body error: \(error)")
            }
        }.catch { error in
            XCTFail("parser error: \(error)")
        }.finally {
            isClosed = true
        }

        try tester.run("GET /hello HTTP/1.1\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nworld").blockingAwait()
        XCTAssertTrue(isClosed)
    }


//
//    func testRequest() throws {
//        var data = """
//        POST /cgi-bin/process.cgi HTTP/1.1\r
//        User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)\r
//        Host: www.tutorialspoint.com\r
//        Content-Type: text/plain\r
//        Content-Length: 5\r
//        Accept-Language: en-us\r
//        Accept-Encoding: gzip, deflate\r
//        Connection: Keep-Alive\r
//        \r
//        hello
//        """.data(using: .utf8) ?? Data()
//
//        let parser = HTTPRequestParser()
//        var message: HTTPRequest?
//        var completed = false
//
//        parser.drain { _message in
//            message = _message
//        }.catch { error in
//            XCTFail("\(error)")
//        }.finally {
//            completed = true
//        }
//
//        XCTAssertNil(message)
//        try parser.next(data.withByteBuffer { $0 }).await(on: loop)
//        parser.close()
//
//        guard let req = message else {
//            XCTFail("No request parsed")
//            return
//        }
//
//        XCTAssertEqual(req.method, .post)
//        XCTAssertEqual(req.headers[.userAgent], "Mozilla/4.0 (compatible; MSIE5.01; Windows NT)")
//        XCTAssertEqual(req.headers[.host], "www.tutorialspoint.com")
//        XCTAssertEqual(req.headers[.contentType], "text/plain")
//        XCTAssertEqual(req.mediaType, .plainText)
//        XCTAssertEqual(req.headers[.contentLength], "5")
//        XCTAssertEqual(req.headers[.acceptLanguage], "en-us")
//        XCTAssertEqual(req.headers[.acceptEncoding], "gzip, deflate")
//        XCTAssertEqual(req.headers[.connection], "Keep-Alive")
//
//        data = try req.body.makeData(max: 100_000).await(on: loop)
//        XCTAssertEqual(String(data: data, encoding: .utf8), "hello")
//        XCTAssert(completed)
//    }
//
//    func testResponse() throws {
//        var data = """
//        HTTP/1.1 200 OK\r
//        Date: Mon, 27 Jul 2009 12:28:53 GMT\r
//        Server: Apache/2.2.14 (Win32)\r
//        Last-Modified: Wed, 22 Jul 2009 19:15:56 GMT\r
//        Content-Length: 7\r
//        Content-Type: text/html\r
//        Connection: Closed\r
//        \r
//        <vapor>
//        """.data(using: .utf8) ?? Data()
//
//        let parser = HTTPResponseParser()
//        var message: HTTPResponse?
//        var completed = false
//
//        parser.drain { _message in
//            message = _message
//        }.catch { error in
//            XCTFail("\(error)")
//        }.finally {
//            completed = true
//        }
//
//        XCTAssertNil(message)
//        try parser.next(data.withByteBuffer { $0 }).await(on: loop)
//        parser.close()
//
//        guard let res = message else {
//            XCTFail("No request parsed")
//            return
//        }
//
//        XCTAssertEqual(res.status, .ok)
//        XCTAssertEqual(res.headers[.date], "Mon, 27 Jul 2009 12:28:53 GMT")
//        XCTAssertEqual(res.headers[.server], "Apache/2.2.14 (Win32)")
//        XCTAssertEqual(res.headers[.lastModified], "Wed, 22 Jul 2009 19:15:56 GMT")
//        XCTAssertEqual(res.headers[.contentLength], "7")
//        XCTAssertEqual(res.headers[.contentType], "text/html")
//        XCTAssertEqual(res.mediaType, .html)
//        XCTAssertEqual(res.headers[.connection], "Closed")
//
//        data = try res.body.makeData(max: 100_000).blockingAwait()
//        XCTAssertEqual(String(data: data, encoding: .utf8), "<vapor>")
//        XCTAssert(completed)
//    }
//
//    func testTooLargeRequest() throws {
//        let data = """
//        POST /cgi-bin/process.cgi HTTP/1.1\r
//        User-Agent: Mozilla/4.0 (compatible; MSIE5.01; Windows NT)\r
//        Host: www.tutorialspoint.com\r
//        Content-Type: text/plain\r
//        Content-Length: 5\r
//        Accept-Language: en-us\r
//        Accept-Encoding: gzip, deflate\r
//        Connection: Keep-Alive\r
//        \r
//        hello
//        """.data(using: .utf8) ?? Data()
//
//        var error = false
//        let p = HTTPRequestParser()
//        p.maxHeaderSize = data.count - 20 // body
//        let parser = p
//
//        var completed = false
//
//        _ = parser.drain { _ in
//            XCTFail()
//        }.catch { _ in
//            error = true
//        }.finally {
//            completed = true
//        }
//
//        try parser.next(data.withByteBuffer { $0 }).await(on: loop)
//        parser.close()
//        XCTAssert(error)
//        XCTAssert(completed)
//    }

//    func testTooLargeResponse() throws {
//        let data = """
//        HTTP/1.1 200 OK\r
//        Date: Mon, 27 Jul 2009 12:28:53 GMT\r
//        Server: Apache/2.2.14 (Win32)\r
//        Last-Modified: Wed, 22 Jul 2009 19:15:56 GMT\r
//        Content-Length: 7\r
//        Content-Type: text/html\r
//        Connection: Closed\r
//        \r
//        <vapor>
//        """.data(using: .utf8) ?? Data()
//
//        var error = false
//        let p = HTTPResponseParser()
//        p.maxHeaderSize = data.count - 20 // body
//        let parser = p.stream(on: loop)
//
//        var completed = false
//
//        _ = parser.drain { _ in
//            XCTFail()
//        }.catch { _ in
//            error = true
//        }.finally {
//            completed = true
//        }
//
//
//        try parser.next(data.withByteBuffer { $0 }).await(on: loop)
//        try parser.next(data.withByteBuffer { $0 }).await(on: loop)
//        parser.close()
//        XCTAssert(error)
//        XCTAssert(completed)
//    }

//    static let allTests = [
//        ("testRequest", testRequest),
//        ("testResponse", testResponse),
//        ("testTooLargeRequest", testTooLargeRequest),
//        ("testTooLargeResponse", testTooLargeResponse),
//    ]
}


