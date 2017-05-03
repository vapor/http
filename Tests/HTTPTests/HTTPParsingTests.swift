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

        _ = try! stream.write(data.makeBytes())


        do {
            let parser = RequestParser()
            let request = try parser.parse(from: stream)

            //MARK: Verify Request
            XCTAssert(request.method == Method.post, "Incorrect method \(request.method)")
            XCTAssert(request.uri.path == "/json", "Incorrect path \(request.uri.path)")
            XCTAssert(request.version.major == 1 && request.version.minor == 1, "Incorrect version")
        } catch {
            XCTFail("Parsing failed: \(error)")
        }
    }

    func testSerializer() throws {
        //MARK: Create Response
        let response = Response(
            status: .enhanceYourCalm,
            headers: [
                "Test": "123",
                "Content-Type": "text/plain"
            ],
            body: "Hello, world!"
        )

        let serializer = ResponseSerializer()
        
        var data = Bytes(repeating: 0, count: 2048)
        do {
            _ = try serializer.serialize(response, into: &data)
        } catch {
            XCTFail("Could not serialize response: \(error)")
        }

        print(data.makeString())
        XCTAssert(data.makeString().contains("HTTP/1.1 420 Enhance Your Calm"))
        XCTAssert(data.makeString().contains("Content-Type: text/plain"))
        XCTAssert(data.makeString().contains("Test: 123"))
        XCTAssert(data.makeString().contains("Content-Length: 13"))
        XCTAssert(data.makeString().contains("\r\n\r\nHello, world!"))
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

    func write(max: Int, from buffer: Bytes) throws -> Int {
        isClosed = false
        self.buffer += buffer
        return buffer.count
    }

    func flush() throws {
        flushedCount += 1
    }

    func read(max: Int, into buffer: inout Bytes) throws -> Int {
        if self.buffer.count == 0 {
            try close()
            buffer = []
            return 0
        }

        if max >= self.buffer.count {
            try close()
            buffer = self.buffer
            self.buffer = []
            return buffer.count
        }

        let data = self.buffer[0..<max].array
        self.buffer.removeFirst(max)

        buffer = data
        return buffer.count
    }
}
