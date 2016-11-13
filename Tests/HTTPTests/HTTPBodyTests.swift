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
        let server = try HTTP.Server<TCPServerStream, Parser<Request>, Serializer<Response>>(host: "0.0.0.0", port: 0, securityLayer: .none)
        let assignedPort = try server.server.stream.localAddress().port

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
            for _ in 0..<8192 {
                let res = try HTTP.Client<TCPClientStream, Serializer<Request>, Parser<Response>>.get("http://0.0.0.0:\(assignedPort)/")
                XCTAssertEqual(res.body.bytes ?? [], "Hello".bytes)
            }
        } catch {
            XCTFail("\(error)")
        }
        
        // WARNING: `server` will keep running in the background since there is no way to stop it. Its socket will continue to exist and the associated port will be in use until the xctest process exits.
    }

    func testClientStreamUsageAsync() throws {
        let server = try HTTP.Server<TCPServerStream, Parser<Request>, Serializer<Response>>(host: "0.0.0.0", port: 0, securityLayer: .none)
        let assignedPort = try server.server.stream.localAddress().port

        struct HelloResponder: HTTP.Responder {
            func respond(to request: Request) throws -> Response {
                return Response(body: "Hello".bytes)
            }
        }
        
        try server.startAsync(responder: HelloResponder(), errors: { err in
            XCTFail("\(err)")
        })
        
        let factor = 1000 * 1000
        let microseconds = 1 * Double(factor)
        usleep(useconds_t(microseconds))
        
        do {
            for _ in 0..<8192 {
                let res = try HTTP.Client<TCPClientStream, Serializer<Request>, Parser<Response>>.get("http://0.0.0.0:\(assignedPort)/")
                XCTAssertEqual(res.body.bytes ?? [], "Hello".bytes)
            }
        } catch {
            XCTFail("\(error)")
        }
    }
}
