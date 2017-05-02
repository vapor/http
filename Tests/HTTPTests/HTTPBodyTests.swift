import XCTest
@testable import HTTP
import Transport
import libc
import Sockets
import Dispatch

class HTTPBodyTests: XCTestCase {
    
    
    func testAsync() throws {
        let server = AsyncServer()
        let responder = Request.Handler { req in
            return Response(status: .ok, body: "Hello world".makeBytes())
        }
        try server.start(responder) { error in
            print(error)
        }
    }
    

    func testBufferParse() throws {
        do {
            let expected = "hello"

            let stream = TestStream()
            try stream.write("GET / HTTP/1.1")
            try stream.writeLineEnd()
            try stream.write("Content-Length: \(expected.characters.count.description)")
            try stream.writeLineEnd()
            try stream.writeLineEnd()
            try stream.write(expected)
            let req = try RequestParser<TestStream>(stream).parse()

            switch req.body {
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
            try stream.write("GET / HTTP/1.1")
            try stream.writeLineEnd()
            try stream.write("Transfer-Encoding: chunked")
            try stream.writeLineEnd()
            try stream.writeLineEnd()
            let chunkStream = ChunkStream(stream: stream)

            try chunkStream.write("hello worl")
            try chunkStream.write("d!")
            try chunkStream.close()

            let req = try RequestParser<TestStream>(stream).parse()

            switch req.body {
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
        let port: Transport.Port = 8338
        
        let serverSocket = try TCPInternetSocket(
            scheme: "http",
            hostname: "0.0.0.0",
            port: port
        )
        let server = try TCPServer(serverSocket)

        struct HelloResponder: HTTP.Responder {
            func respond(to request: Request) throws -> Response {
                return Response(status: .ok, body: "Hello".makeBytes())
            }
        }

        let group = DispatchGroup()
        group.enter()
        background {
            do {
                group.leave()
                try server.start(HelloResponder(), errors: { err in
                    XCTFail("\(err)")
                })
            } catch {
                group.leave()
                XCTFail("\(error)")
            }
        }
        group.wait()
        Thread.sleep(forTimeInterval: 2)

        do {
            for _ in 0..<8192 {
                let clientSocket = try TCPInternetSocket(
                    scheme: "http",
                    hostname: "0.0.0.0",
                    port: port
                )
                let req = Request(
                    method: .get,
                    uri: "http://0.0.0.0:\(port)/"
                )
                
                let res = try TCPClient(clientSocket)
                    .respond(to: req)
                
                XCTAssertEqual(res.body.bytes ?? [], "Hello".makeBytes())
            }
        } catch {
            XCTFail("\(error)")
        }
        
        // WARNING: `server` will keep running in the background since there is no way to stop it. Its socket will continue to exist and the associated port will be in use until the xctest process exits.
    }
    
    func testBigBody() throws {
        let httpbin = try TCPInternetSocket(scheme: "http", hostname: "httpbin.org", port: 80)
        let client = try TCPClient(httpbin)
        let req = Request(method: .get, uri: "http://httpbin.org/bytes/8192")
        let res = try client.respond(to: req)
        XCTAssertEqual(res.body.bytes?.count, 8192)
        try httpbin.close()
    }
    
    static var allTests = [
        ("testBufferParse", testBufferParse),
        ("testChunkedParse", testChunkedParse),
        ("testClientStreamUsage", testClientStreamUsage)
    ]
}
