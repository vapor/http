import Foundation
import XCTest

import Transport
@testable import HTTP

class HTTPParsingTests: XCTestCase {
    static let allTests = [
       ("testParser", testParser),
       ("testSerializer", testSerializer)
    ]

    func testParser() {
        let stream = TestStream()

        //MARK: Create Request
        let content = "{\"hello\": \"world\"}"

        var data = "POST /json HTTP/1.1\r\n"
        data += "Accept-Encoding: gzip, deflate\r\n"
        data += "Accept: */*\r\n"
        data += "Accept-Language: en-us\r\n"
        data += "Cookie: 1=1;2=2\r\n"
        data += "Content-Type: application/json; charset=utf-8\r\n"
        data += "Content-Length: \(content.characters.count)\r\n"
        data += "\r\n"
        data += content

        try! stream.send(data.makeBytes())


        do {
            let request = try Parser<Request, TestStream>(stream: stream).parse()

            //MARK: Verify Request
            XCTAssert(request.method == Method.post, "Incorrect method \(request.method)")
            XCTAssert(request.uri.path == "/json", "Incorrect path \(request.uri.path)")
            XCTAssert(request.version.major == 1 && request.version.minor == 1, "Incorrect version")
        } catch {
            XCTFail("Parsing failed: \(error)")
        }
    }

    func testSerializer() {
        //MARK: Create Response
        let response = Response(
            status: .enhanceYourCalm,
            headers: [
                "Test": "123",
                "Content-Type": "text/plain"
            ],
            chunked: { stream in
                try stream.send("Hello, world")
                try stream.close()
            }
        )

        let stream = TestStream()
        let serializer = Serializer<Response, TestStream>(stream: stream)
        do {
            try serializer.serialize(response)
        } catch {
            XCTFail("Could not serialize response: \(error)")
        }

        let data = try! stream.receive(max: 2048)

        XCTAssert(data.makeString().contains("HTTP/1.1 420 Enhance Your Calm"))
        XCTAssert(data.makeString().contains("Content-Type: text/plain"))
        XCTAssert(data.makeString().contains("Test: 123"))
        XCTAssert(data.makeString().contains("Transfer-Encoding: chunked"))
        XCTAssert(data.makeString().contains("\r\n\r\nC\r\nHello, world\r\n0\r\n\r\n"))
    }
}

final class TestStream: InternetStream, DuplexStream {
    var hostname: String {
        return "1.2.3.4"
    }

    var port: Transport.Port {
        return 5678
    }

    var scheme: String {
        return "https"
    }

    convenience init(scheme: String, hostname: String, port: Transport.Port) throws {
        self.init()
    }

    var isClosed: Bool
    var buffer: Bytes
    var timeout: Double = -1
    // number of times flush was called
    var flushedCount = 0

    func setTimeout(_ timeout: Double) throws {
            self.timeout = timeout
    }

    init() {
        isClosed = false
        buffer = []
    }

    func close() throws {
        if !isClosed {
            isClosed = true
        }
    }

    func send(_ bytes: Bytes) throws {
        isClosed = false
        buffer += bytes
    }

    func flush() throws {
        flushedCount += 1
    }

    func receive(max: Int) throws -> Bytes {
        if buffer.count == 0 {
            try close()
            return []
        }

        if max >= buffer.count {
            try close()
            let data = buffer
            buffer = []
            return data
        }

        let data = buffer[0..<max]
        buffer.removeFirst(max)

        return Bytes(data)
    }
}
