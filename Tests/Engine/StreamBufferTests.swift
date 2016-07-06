import Foundation
import XCTest

@testable import Engine

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
