@testable import WebSocket
import Bits
import Service
import HTTP
import TCP
import Async
import XCTest

final class WebSocketTests : XCTestCase {
    func testUpgrade() throws {
        let worker = try DefaultEventLoop(label: "codes.vapor.test.worker")
        let serverSocket = try TCPSocket(isNonBlocking: true)
        let server = try TCPServer(socket: serverSocket)
        
        try server.start(hostname: "localhost", port: 8090, backlog: 128)
        Thread.async {
            let webserver = HTTPServer(
                acceptStream: server.stream(on: worker).map(to: TCPSocketStream.self) {
                    $0.socket.stream(on: worker) { _, error in
                        XCTFail("\(error)")
                    }
                },
                worker: worker,
                responder: WebSocketResponder()
            )
            webserver.onError = { XCTFail("\($0)") }
            worker.runLoop()
        }

        let clientSocket = try TCPSocket(isNonBlocking: false)
        let client = try TCPClient(socket: clientSocket)
        try client.connect(hostname: "localhost", port: 8090)
        let write = Data("""
        GET / HTTP/1.1\r
        Connection: Upgrade\r
        Upgrade: websocket\r
        Sec-WebSocket-Key: yQWympdS3/3+7EXhPH+P/A==\r
        Sec-WebSocket-Version: 13\r
        Content-Length: 0\r
        \r

        """.utf8)
        _ = try client.socket.write(write)
        let read = try client.socket.read(max: 512)
        let string = String(data: read, encoding: .utf8)
        XCTAssertEqual(string, """
        HTTP/1.1 101 Upgrade\r
        Upgrade: websocket\r
        Connection: Upgrade\r
        Sec-WebSocket-Accept: U5ZWHrbsu7snP3DY1Q5P3e8AkOk=\r
        Content-Length: 0\r
        \r

        """)

        client.close()
        server.stop()
    }
    
    func testInvalidUpgrade() {
        let request = HTTPRequest()
        
        XCTAssertThrowsError(try WebSocket.upgradeResponse(for: request, with: .init()))
    }
    
    func testMasklessFrame() {
        let data = Data("hello".utf8)
        
        let masklessFrame = data.withByteBuffer { buffer in
            return Frame(op: .text, payload: buffer, mask: nil)
        }
        
        XCTAssertEqual(Data(buffer: masklessFrame.payload), data)
        masklessFrame.mask()
        XCTAssertEqual(Data(buffer: masklessFrame.payload), data)
        masklessFrame.unmask()
        XCTAssertEqual(Data(buffer: masklessFrame.payload), data)
    }
    
    func testMaskedFrame() {
        let data = Data("hello".utf8)
        
        let masklessFrame = data.withByteBuffer { buffer in
            return Frame(op: .text, payload: buffer, mask: [0x51, 0x42, 0x63, 0x12])
        }
        
        XCTAssertEqual(Data(buffer: masklessFrame.payload), data)
        masklessFrame.mask()
        XCTAssertNotEqual(Data(buffer: masklessFrame.payload), data)
        masklessFrame.unmask()
        XCTAssertEqual(Data(buffer: masklessFrame.payload), data)
    }
    
    func testEmptyMask() {
        let data = Data("hello".utf8)
        
        let masklessFrame = data.withByteBuffer { buffer in
            return Frame(op: .text, payload: buffer, mask: [0,0,0,0])
        }
        
        XCTAssertEqual(Data(buffer: masklessFrame.payload), data)
        masklessFrame.mask()
        XCTAssertEqual(Data(buffer: masklessFrame.payload), data)
        masklessFrame.unmask()
        XCTAssertEqual(Data(buffer: masklessFrame.payload), data)
    }
    
    func testFrameSerializer() {
        let data = Data("hello".utf8)
        let mask: [UInt8] = [173,14,61,12]
        
        let frame = data.withByteBuffer { buffer in
            return Frame(op: .text, payload: buffer, mask: mask)
        }
        
        guard case .complete(let buffer) = FrameSerializer(masking: true).serialize(frame, state: nil) else {
            XCTFail()
            return
        }
        
        // Not masked yet
        guard buffer.count == 11 else {
            XCTAssertEqual(buffer.count, 11)
            return
        }
        
        XCTAssertEqual(buffer[0] & 0b10000000, 0b10000000)
        
        frame.unmask()
        XCTAssertEqual(buffer[0] & 0b00001111, 0x01)
        
        frame.mask()
        XCTAssertEqual(buffer[1] & 0b10000000, 0b10000000)
        
        XCTAssertEqual(buffer[1] & 0b01111111, numericCast(data.count))
        
        XCTAssertEqual(buffer[2], mask[0])
        XCTAssertEqual(buffer[3], mask[1])
        XCTAssertEqual(buffer[4], mask[2])
        XCTAssertEqual(buffer[5], mask[3])
        
        frame.mask()
        var i = 0
        var message = data.makeIterator()
        for byte in frame.payload {
            XCTAssertEqual(message.next(), byte ^ mask[i])

            i += 1
            
            if i == 4 {
                i = 0
            }
        }
        
        frame.unmask()
        XCTAssertEqual(Array(buffer[6...]), Array(data))
        
        // prevent dealloc
        _ = frame
    }
    
    func testFrameParser() throws {
        var data: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        let mask: [UInt8] = [173,14,61,12]
        
        let message = Data([
            0b10000001, // final text
            0b10000111, // 7 masked bytes
            mask[0], mask[1], mask[2], mask[3], // mask
            data[0] ^ mask[0],
            data[1] ^ mask[1],
            data[2] ^ mask[2],
            data[3] ^ mask[3],
            data[4] ^ mask[0],
            data[5] ^ mask[1],
            data[6] ^ mask[2],
        ])
        
        let parser = FrameParser(worker: try DefaultEventLoop(label: "test"))
        
        let state = try message.withByteBuffer { buffer in
            return try parser.parseBytes(from: buffer, partial: nil)
        }
        
        switch try state.requireCompleted() {
        case .completed(let n, let frame):
            XCTAssertEqual(n, message.count)
            XCTAssertNotEqual(Array(frame.buffer), data)
            
            frame.unmask()
            XCTAssertEqual(Array(frame.payload), data)
        default:
            XCTFail("\(state)")
        }
    }
    
    func testComplexMesasgeSituations() throws {
        var data: [UInt8] = [0, 1, 2, 3, 4, 5, 6]
        let mask: [UInt8] = [173,14,61,12]
        
        let message = Data([
            0b10000001, // final text
            0b10000111, // 7 masked bytes
            mask[0], mask[1], mask[2], mask[3], // mask
            data[0] ^ mask[0],
            data[1] ^ mask[1],
            data[2] ^ mask[2],
            data[3] ^ mask[3],
            data[4] ^ mask[0],
            data[5] ^ mask[1],
            data[6] ^ mask[2],
        ])
        
        let loop = try DefaultEventLoop(label: "test")
        
        let parser = FrameParser(worker: loop)
        
        // Last byte should be complete
        for offset in 0..<message.count - 1 {
            let state = try message.withByteBuffer { buffer -> Future<ByteParserResult<FrameParser>> in
                let buffer = ByteBuffer(start: buffer.baseAddress?.advanced(by: offset), count: 1)
                return try parser.parseBytes(from: buffer, partial: nil)
            }
            
            guard case .uncompleted = try state.requireCompleted() else {
                XCTFail()
                return
            }
        }
        
        let state = try message.withByteBuffer { buffer in
            return try parser.parseBytes(from: buffer, partial: nil)
        }
        
        guard case .completed(_, let frame) = try state.requireCompleted() else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(Data(buffer: frame.buffer), message)
    }

    static let allTests = [
        ("testUpgrade", testUpgrade),
        ("testInvalidUpgrade", testInvalidUpgrade),
        ("testMasklessFrame", testMasklessFrame),
        ("testMaskedFrame", testMaskedFrame),
        ("testEmptyMask", testEmptyMask),
        ("testFrameParser", testFrameParser),
        ("testComplexMesasgeSituations", testComplexMesasgeSituations),
    ]
}

final class WebSocketResponder: HTTPResponder {
    var serverSide: WebSocket?

    init() {}

    func respond(to req: HTTPRequest, on worker: Worker) throws -> Future<HTTPResponse> {
        let response = try WebSocket.upgradeResponse(for: req, with: WebSocketSettings()) { websocket in
            websocket.onString { ws, text in
                ws.send(string: String(text.reversed()))
            }
            
            websocket.onError { ws, error in
                XCTFail("\(error)")
            }
            
            websocket.onClose { _, _ in
                print("closed")
            }

            self.serverSide = websocket
        }

        return Future(response)
    }
}
