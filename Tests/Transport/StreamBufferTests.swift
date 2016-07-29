import Foundation
import XCTest

import Core
import SocksCore
@testable import Transport


class SockStreamTests: XCTestCase {
    func testTCPInternetSocket() throws {
        // from SocksExampleTCPClient
        let stream = try TCPProgramStream(host: "google.com", port: 80)
        let sock = stream.stream
        try sock.setTimeout(10)
        try sock.connect()
        try sock.send("GET /\r\n\r\n".bytes)
        try sock.flush()
        let received = try sock.receive(max: 2048)
        try sock.close()

        // Receiving the raw google homepage
        XCTAssert(received.string.contains("<title>Google</title>"))
    }

    func testTCPInternetSocketThrows() throws {
        // from SocksExampleTCPClient
        let stream = try TCPProgramStream(host: "google.com", port: 80)
        let sock = stream.stream

        do {
            try sock.send("GET /\r\n\r\n".bytes)
            XCTFail("should throw -- not connected")
        } catch {}

        do {
            _ = try sock.receive(max: 2048)
            XCTFail("should throw -- not connected")
        } catch {}
    }

    func testTCPServer() throws {
        let serverStream = try TCPServerStream(host: "0.0.0.0", port: 2653)
        _ = try background {
            do {
                let connection = try serverStream.accept()
                let message = try connection.receive(max: 2048).string
                XCTAssert(message == "Hello, World!")
            } catch {
                XCTFail("failed w/ \(error)")
            }
        }

        let program = try TCPClientStream(host: "0.0.0.0", port: 2653)
        let sock = try program.connect()
        try sock.send("Hello, World!".bytes)
    }

    func testSecurityLayerStrings() {
        let schemes: [(String, SecurityLayer)] = [
            ("https", .tls),
            ("http", .none),
            ("wss", .tls),
            ("ws", .none)
        ]

        schemes.forEach { scheme, securityLayer in
            XCTAssert(scheme.securityLayer == securityLayer)
        }
    }

    func testFoundationStream() throws {
        #if !os(Linux)
            // will default to underlying FoundationStream for TLS.
            let clientStream = try FoundationStream(host: "google.com", port: 443, securityLayer: .tls)
            let connection = try clientStream.connect()
            XCTAssert(!connection.closed)
            do {
                try connection.setTimeout(30)
                XCTFail("Foundation stream should throw on timeout set")
            } catch {}
            try connection.send("GET / \r\n\r\n".bytes)
            try connection.flush()
            let received = try connection.receive(max: 2048)
            try connection.close()
            
            XCTAssert(connection.closed)
            // Receiving the raw google homepage
            XCTAssert(received.string.contains("<title>Google</title>"))
        #endif
    }

    func testFoundationThrows() throws {
        #if !os(Linux)
            // will default to underlying FoundationStream for TLS.
            let clientStream = try FoundationStream(host: "nothere", port: 9999)
            let connection = try clientStream.connect()
            // should skip empty buffer
            try connection.send([])

            do {
                try connection.send("hi".bytes)
                XCTFail("Foundation stream should throw on send not valid")
            } catch {}

            do {
                _ = try connection.receive(max: 2048)
                XCTFail("Foundation stream should throw on send not valid")
            } catch {}
        #endif
    }

    func testFoundationEventCode() throws {
        #if !os(Linux)
            // will default to underlying FoundationStream for TLS.
            let clientStream = try FoundationStream(host: "google.com", port: 443, securityLayer: .tls)
            let connection = try clientStream.connect()
            XCTAssertFalse(connection.closed)
            // Force Foundation.Stream delegate
            clientStream.stream(clientStream.input, handle: .endEncountered)
            XCTAssertTrue(connection.closed)
        #endif
    }


}

class StreamBufferTests: XCTestCase {
    static let allTests = [
        ("testStreamBufferSending", testStreamBufferSending),
        ("testStreamBufferSendingImmediateFlush", testStreamBufferSendingImmediateFlush),
        ("testStreamBufferReceiving", testStreamBufferReceiving),
        ("testStreamBufferSkipEmpty", testStreamBufferSkipEmpty),
        ("testStreamBufferFlushes", testStreamBufferFlushes),
        ("testStreamBufferMisc", testStreamBufferMisc)
    ]

    lazy var testStream: TestStream! = TestStream()
    lazy var streamBuffer: StreamBuffer! = StreamBuffer(self.testStream)

    override func tearDown() {
        super.tearDown()
        // reset
        testStream = nil
        streamBuffer = nil
    }

    func testStreamBufferSending() throws {
        try streamBuffer.send([1,2,3,4,5])
        XCTAssert(testStream.buffer == [], "underlying shouldn't have sent bytes yet")
        try streamBuffer.flush()
        XCTAssert(testStream.buffer == [1,2,3,4,5], "buffer should have sent bytes")
    }

    func testStreamBufferSendingImmediateFlush() throws {
        try streamBuffer.send([1,2,3,4,5], flushing: true)
        XCTAssert(testStream.buffer == [1,2,3,4,5], "buffer should have sent bytes")
    }

    func testStreamBufferReceiving() throws {
        // loads test stream
        try testStream.send([1,2,3,4,5])

        let first = try streamBuffer.receive()
        XCTAssert(first == 1)
        XCTAssert(testStream.buffer == [], "test stream should be entirely received by buffer")

        let remaining = try streamBuffer.receive(max: 200)
        XCTAssert(remaining == [2,3,4,5])
    }

    func testStreamBufferSkipEmpty() throws {
        try streamBuffer.send([], flushing: true)
        XCTAssert(testStream.flushedCount == 0, "should not attempt to flush empty buffer")
    }

    func testStreamBufferFlushes() throws {
        try streamBuffer.send(1)
        try streamBuffer.flush()
        XCTAssert(testStream.flushedCount == 1, "should have flushed")
    }

    func testStreamBufferMisc() throws {
        try streamBuffer.close()
        XCTAssert(testStream.closed, "stream buffer should close underlying stream")
        XCTAssert(streamBuffer.closed, "stream buffer should reflect closed status of underlying stream")

        try streamBuffer.setTimeout(42)
        XCTAssert(testStream.timeout == 42, "stream buffer should set underlying timeout")
    }
}
