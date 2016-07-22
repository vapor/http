import Foundation
import XCTest
import libc

import Core
@testable import WebSockets


/*
    Examples from: https://tools.ietf.org/html/rfc6455#section-5.7

    o  A single-frame unmasked text message

    *  0x81 0x05 0x48 0x65 0x6c 0x6c 0x6f (contains "Hello")

    o  A single-frame masked text message

    *  0x81 0x85 0x37 0xfa 0x21 0x3d 0x7f 0x9f 0x4d 0x51 0x58
    (contains "Hello")

    o  A fragmented unmasked text message

    *  0x01 0x03 0x48 0x65 0x6c (contains "Hel")

    *  0x80 0x02 0x6c 0x6f (contains "lo")


    Fette & Melnikov             Standards Track                   [Page 38]

    RFC 6455                 The WebSocket Protocol            December 2011


    o  Unmasked Ping request and masked Ping response

    *  0x89 0x05 0x48 0x65 0x6c 0x6c 0x6f (contains a body of "Hello",
    but the contents of the body are arbitrary)

    *  0x8a 0x85 0x37 0xfa 0x21 0x3d 0x7f 0x9f 0x4d 0x51 0x58
    (contains a body of "Hello", matching the body of the ping)

    o  256 bytes binary message in a single unmasked frame

    *  0x82 0x7E 0x0100 [256 bytes of binary data]

    o  64KiB binary message in a single unmasked frame

    *  0x82 0x7F 0x0000000000010000 [65536 bytes of binary data]
*/
class WebSocketSerializationTests: XCTestCase {
    static let allTests = [
        ("testSingleFrameUnmaskedTextMessage", testSingleFrameUnmaskedTextMessage),
        ("testSingleFrameMaskedTextMessage", testSingleFrameMaskedTextMessage),
        ("testFragmentedUnmaskedTextMessageOne", testFragmentedUnmaskedTextMessageOne),
        ("testFragmentedUnmaskedTextMessageTwo", testFragmentedUnmaskedTextMessageTwo),
        ("testUnmaskedPingRequest", testUnmaskedPingRequest),
        ("testMaskedPongResponse", testMaskedPongResponse),
        ("test256BytesBinarySingleUnmaskedFrame", test256BytesBinarySingleUnmaskedFrame),
        ("testSixtyFourKiBSingleUnmaskedFrame", testSixtyFourKiBSingleUnmaskedFrame),
    ]

    func testSingleFrameUnmaskedTextMessage() throws {
        let input: [Byte] = [0x81, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
        let test = TestStream()
        try test.send(input)
        let msg = try FrameParser(stream: test).acceptFrame()
        let str = msg.payload.string
        XCTAssert(str == "Hello")

        let header = msg.header
        XCTAssert(header.fin)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == false)
        XCTAssert(header.opCode == .text)
        XCTAssert(header.payloadLength == 5)

        // Test return to bytes
        assertSerialized(msg, equals: input)
    }

    func testSingleFrameMaskedTextMessage() throws {
        let input: [Byte] = [0x81, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58]
        let test = TestStream()
        try test.send(input)
        let msg = try FrameParser(stream: test).acceptFrame()
        let str = msg.payload.string
        XCTAssert(str == "Hello")

        let header = msg.header
        XCTAssert(header.fin)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == true)
        XCTAssert(header.opCode == .text)
        XCTAssert(header.payloadLength == 5)

        // Test return to bytes
        assertSerialized(msg, equals: input)
    }

    /*
        o  A fragmented unmasked text message

        *  0x01 0x03 0x48 0x65 0x6c (contains "Hel")

        *  0x80 0x02 0x6c 0x6f (contains "lo")
    */
    func testFragmentedUnmaskedTextMessageOne() throws {
        let input: [Byte] = [0x01, 0x03, 0x48, 0x65, 0x6c]
        let test = TestStream()
        try test.send(input)
        let msg = try FrameParser(stream: test).acceptFrame()
        XCTAssert(msg.isFragment)
        XCTAssert(msg.isFragmentHeader)
        XCTAssertFalse(msg.isControlFrame)

        let str = try msg.payload.toString()
        XCTAssert(str == "Hel")

        let header = msg.header
        XCTAssert(header.fin == false)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == false)
        XCTAssert(header.opCode == .text)
        XCTAssert(header.payloadLength == 3)

        // Test return to bytes
        assertSerialized(msg, equals: input)
    }

    func testFragmentedUnmaskedTextMessageTwo() throws {
        let input: [Byte] = [0x80, 0x02, 0x6c, 0x6f]
        let test = TestStream()
        try test.send(input)
        let msg = try FrameParser(stream: test).acceptFrame()
        XCTAssert(msg.isFragment)
        XCTAssert(msg.isFragmentFooter)
        XCTAssertFalse(msg.isControlFrame)

        let str = try msg.payload.toString()
        XCTAssert(str == "lo")

        let header = msg.header
        XCTAssert(header.fin == true)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == false)
        XCTAssert(header.opCode == .continuation)
        XCTAssert(header.payloadLength == 2)

        // Test return to bytes
        assertSerialized(msg, equals: input)
    }

    /*

     Unmasked Ping request and masked Ping response
     *  0x89 0x05 0x48 0x65 0x6c 0x6c 0x6f (contains a body of "Hello",
     but the contents of the body are arbitrary)

     *  0x8a 0x85 0x37 0xfa 0x21 0x3d 0x7f 0x9f 0x4d 0x51 0x58
     (contains a body of "Hello", matching the body of the ping)
     */
    func testUnmaskedPingRequest() throws {
        let input: [Byte] = [0x89, 0x05, 0x48, 0x65, 0x6c, 0x6c, 0x6f]
        let test = TestStream()
        try test.send(input)
        let msg = try FrameParser(stream: test).acceptFrame()
        XCTAssert(msg.isControlFrame)

        // is Hello, but message doesn't matter
        let str = try msg.payload.toString()
        XCTAssert(str == "Hello")

        let header = msg.header
        XCTAssert(header.fin == true)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == false)
        XCTAssert(header.opCode == .ping)
        XCTAssert(header.payloadLength == 5)

        // Test return to bytes
        assertSerialized(msg, equals: input)
    }

    func testMaskedPongResponse() throws {
        /*
         Client to Server MUST be masked
         */
        let input: [Byte] = [0x8a, 0x85, 0x37, 0xfa, 0x21, 0x3d, 0x7f, 0x9f, 0x4d, 0x51, 0x58]
        let test = TestStream()
        try test.send(input)
        let msg = try FrameParser(stream: test).acceptFrame()
        XCTAssert(msg.isControlFrame)

        // is Hello, but message doesn't matter. Must match `ping` payload
        let str = try msg.payload.toString()
        XCTAssert(str == "Hello")

        let header = msg.header
        XCTAssert(header.fin == true)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == true)
        XCTAssert(header.opCode == .pong)
        XCTAssert(header.payloadLength == 5)

        // Test return to bytes
        assertSerialized(msg, equals: input)
    }

    /*
     o  256 bytes binary message in a single unmasked frame

     *  0x82 0x7E 0x0100 [256 bytes of binary data]
     */
    func test256BytesBinarySingleUnmaskedFrame() throws {
        // ensure 16 bit lengths
        var randomBinary: [Byte] = []
        (1...256).forEach { _ in
            let random = UInt8.random()
            randomBinary.append(random)
        }

        // 256 as two UInt8
        let twoFiftySix: [Byte] = [0x01, 0x00]
        let headerBytes: [Byte] = [0x82, 0x7E] + twoFiftySix

        let input = headerBytes + randomBinary
        let test = TestStream()
        try test.send(input)
        let msg = try FrameParser(stream: test).acceptFrame()
        XCTAssertFalse(msg.isControlFrame)

        let payload = msg.payload
        XCTAssert(payload == randomBinary)

        let header = msg.header
        XCTAssert(header.fin == true)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == false)
        XCTAssert(header.opCode == .binary)
        XCTAssert(header.payloadLength == 256)

        // Test return to bytes
        assertSerialized(msg, equals: input)
    }

    /*
     If payload length is > can fit in 2 bytes, will become 8 byte length

     o  64KiB binary message in a single unmasked frame

     *  0x82 0x7F 0x0000000000010000 [65536 bytes of binary data]
     */
    func testSixtyFourKiBSingleUnmaskedFrame() throws {
        // ensure 64 bit lengths
        var randomBinary: [Byte] = []
        (1...65536).forEach { _ in
            let random = UInt8.random()
            randomBinary.append(random)
        }

        // 65536 as 8 UInt8
        let sixFiveFiveThreeSix: [Byte] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00]
        let headerBytes: [Byte] = [0x82, 0x7F] + sixFiveFiveThreeSix

        let input = headerBytes + randomBinary
        let test = TestStream()
        try test.send(input)
        let msg = try FrameParser(stream: test).acceptFrame()
        XCTAssertFalse(msg.isControlFrame)

        let payload = msg.payload
        XCTAssert(payload == randomBinary)

        let header = msg.header
        XCTAssert(header.fin == true)
        XCTAssert(header.rsv1 == false)
        XCTAssert(header.rsv2 == false)
        XCTAssert(header.rsv3 == false)
        XCTAssert(header.isMasked == false)
        XCTAssert(header.opCode == .binary)
        XCTAssert(header.payloadLength == 65536)

        // Test return to bytes
        assertSerialized(msg, equals: input)
    }

    private func assertSerialized(_ frame: WebSocket.Frame, equals bytes: [Byte]) {
        let serializer = FrameSerializer(frame)
        let serialized = serializer.serialize()
        XCTAssert(serialized == bytes)
    }
}

class WebSocketKeyTests: XCTestCase {
    static var allTests: [(String, (WebSocketKeyTests) -> () throws -> Void)] {
        return [
            ("testExchangeKey", testExchangeKey)
        ]
    }

    /*
        https://tools.ietf.org/html/rfc6455#section-1.3

        Concretely, if as in the example above, the |Sec-WebSocket-Key|
        header field had the value "dGhlIHNhbXBsZSBub25jZQ==", the server
        would concatenate the string "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        to form the string "dGhlIHNhbXBsZSBub25jZQ==258EAFA5-E914-47DA-95CA-
        C5AB0DC85B11".  The server would then take the SHA-1 hash of this,
        giving the value 0xb3 0x7a 0x4f 0x2c 0xc0 0x62 0x4f 0x16 0x90 0xf6
        0x46 0x06 0xcf 0x38 0x59 0x45 0xb2 0xbe 0xc4 0xea.  This value is
        then base64-encoded (see Section 4 of [RFC4648]), to give the value
        "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=".  This value would then be echoed in
        the |Sec-WebSocket-Accept| header field.
    */
    func testExchangeKey() throws {
        let requestKey = "dGhlIHNhbXBsZSBub25jZQ=="
        let acceptKey = WebSocket.exchange(requestKey: requestKey)
        XCTAssert(acceptKey == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=")
    }
}

import Engine
final class TestStream: Engine.Stream {
    var closed: Bool
    var buffer: Bytes

    func setTimeout(_ timeout: Double) throws {

    }

    init() {
        closed = false
        buffer = []
    }

    func close() throws {
        if !closed {
            closed = true
        }
    }

    func send(_ bytes: Bytes) throws {
        closed = false
        buffer += bytes
    }

    func flush() throws {

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
