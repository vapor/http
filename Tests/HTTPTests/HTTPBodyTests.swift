import XCTest
@testable import HTTP
import Transport
import libc
import Sockets

class HTTPBodyTests: XCTestCase {
    static var allTests = [
        ("testBufferParse", testBufferParse),
        ("testChunkedParse", testChunkedParse),
        ("testClientStreamUsage", testClientStreamUsage)
    ]

    func testBufferParse() throws {
        do {
            let expected = "hello"

            let stream = TestStream()
            try stream.write(expected)
            let body = try Parser<Request, TestStream>(stream: stream).parseBody(with: ["content-length": expected.characters.count.description])

            switch body {
            case .data(let data):
                XCTAssertEqual(data.makeString(), expected)
            default:
                XCTFail("Body not buffer")
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func testChunkedParse() {
        do {
            let expected = "hello world!"

            let stream = TestStream()
            let chunkStream = ChunkStream(stream: stream)

            try chunkStream.write("hello worl")
            try chunkStream.write("d!")

            let body = try Parser<Request, TestStream>(stream: stream).parseBody(with: ["transfer-encoding": "chunked"])

            switch body {
            case .data(let data):
                XCTAssertEqual(data.makeString(), expected)
            default:
                XCTFail("Body not buffer")
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func testClientStreamUsage() throws {
        let serverSocket = try TCPInternetSocket(scheme: "http", hostname: "0.0.0.0", port: 8942)
        let server = try TCPServer(serverSocket)

        struct HelloResponder: HTTP.Responder {
            func respond(to request: Request) throws -> Response {
                return Response(body: "Hello".makeBytes())
            }
        }

        background {
            try! server.start(HelloResponder(), errors: { err in
                XCTFail("\(err)")
            })
        }

        let factor = 1000 * 1000
        let microseconds = 1 * Double(factor)
        usleep(useconds_t(microseconds))

        do {
            for _ in 0..<8192 {
                let clientSocket = try TCPInternetSocket(scheme: "http", hostname: "0.0.0.0", port: 8942)
                let res = try TCPClient(clientSocket)
                    .respond(to: Request(method: .get, uri: "http://0.0.0.0:\(8942)/"))
                XCTAssertEqual(res.body.bytes ?? [], "Hello".makeBytes())
            }
        } catch {
            XCTFail("\(error)")
        }
        
        // WARNING: `server` will keep running in the background since there is no way to stop it. Its socket will continue to exist and the associated port will be in use until the xctest process exits.
    }
}
