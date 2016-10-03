import XCTest
@testable import HTTP
import Transport
import libc

class HTTPBodyTests: XCTestCase {
    static var allTests = [
        ("testBufferParse", testBufferParse),
        ("testChunkedParse", testChunkedParse),
        ("testClientStreamUsage", testClientStreamUsage),
    ]

    func testBufferParse() throws {
        do {
            let expected = "hello"

            let stream = TestStream()
            try stream.send(expected)
            let body = try Parser<Request>(stream: stream).parseBody(with: ["content-length": expected.characters.count.description])

            switch body {
            case .data(let data):
                XCTAssertEqual(data.string, expected)
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

            try chunkStream.send("hello worl")
            try chunkStream.send("d!")

            let body = try Parser<Request>(stream: stream).parseBody(with: ["transfer-encoding": "chunked"])

            switch body {
            case .data(let data):
                XCTAssertEqual(data.string, expected)
            default:
                XCTFail("Body not buffer")
            }
        } catch {
            XCTFail("\(error)")
        }
    }

    func testClientStreamUsage() throws {
        let server = try HTTP.Server<TCPServerStream, Parser<Request>, Serializer<Response>>(host: "0.0.0.0", port: 8637, securityLayer: .none)

        struct HelloResponder: HTTP.Responder {
            func respond(to request: Request) throws -> Response {
                return Response(body: "Hello".bytes)
            }
        }

        try background {
            try! server.start(responder: HelloResponder(), errors: { err in
                XCTFail("\(err)")
            })
        }

        let factor = 1000 * 1000
        let microseconds = 1 * Double(factor)
        usleep(useconds_t(microseconds))

        do {
            for _ in 0..<16384 {
                let res = try HTTP.Client<TCPClientStream, Serializer<Request>, Parser<Response>>.get("http://0.0.0.0:8637/")
                XCTAssertEqual(res.body.bytes ?? [], "Hello".bytes)
            }
        } catch {
            XCTFail("\(error)")
        }
    }
}
