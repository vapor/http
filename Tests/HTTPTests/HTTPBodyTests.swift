import XCTest
@testable import HTTP
import Transport
import libc
import Sockets
import Dispatch
import Random

class HTTPBodyTests: XCTestCase {

    func testBufferParse() throws {
        do {
            let expected = "hello"

            let stream = TestStream()
            _ = try stream.write("GET / HTTP/1.1")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Content-Length: \(expected.characters.count.description)")
            _ = try stream.writeLineEnd()
            _ = try stream.writeLineEnd()
            _ = try stream.write(expected)
            let req = try RequestParser(maxSize: 100_000).parse(from: stream)

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
            _ = try stream.write("GET / HTTP/1.1")
            _ = try stream.writeLineEnd()
            _ = try stream.write("Transfer-Encoding: chunked")
            _ = try stream.writeLineEnd()
            _ = try stream.writeLineEnd()
            let chunkStream = ChunkStream(stream)

            try chunkStream.write("hello worl")
            try chunkStream.write("d!")
            try chunkStream.close()
            
            let req = try RequestParser(maxSize: 100_000).parse(from: stream)

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
        let port: Transport.Port = 8231
        
        let server = try TCPServer(
            scheme: "http",
            hostname: "0.0.0.0",
            port: port,
            maxRequestSize: 100_000
        )

        let responder = BasicResponder { request in
            return Response(status: .ok, body: "Hello \(request.uri.path)".makeBytes())
        }

        let group = DispatchGroup()
        group.enter()
        background {
            do {
                group.leave()
                try server.start(responder, errors: { err in
                    XCTFail("\(err)")
                })
            } catch {
                XCTFail("\(error)")
            }
        }
        group.wait()
        Thread.sleep(forTimeInterval: 1)
        
        // spin up 2k requests across 8 threads
        for _ in 1...8 {
            group.enter()
            background {
                for _ in 0..<8 {
                    do {
                        let clientSocket = try TCPInternetSocket(
                            scheme: "http",
                            hostname: "127.0.0.1",
                            port: port
                        )
                        
                        let path = try "/" + OSRandom.bytes(count: 16).hexEncoded.makeString()
                        
                        let req = Request(
                            method: .get,
                            uri: "http://127.0.0.1:\(port)\(path)"
                        )
                        
                        let res = try TCPClient(clientSocket, maxResponseSize: 100_000)
                            .respond(to: req)
                        
                        XCTAssertEqual(res.body.bytes?.makeString(), "Hello \(path)")
                    } catch {
                        XCTFail("\(error)")
                    }
                }
                group.leave()
            }
        }
        // WARNING: `server` will keep running in the background since there is no way to stop it. Its socket will continue to exist and the associated port will be in use until the xctest process exits.
    }
    
    func testBigBody() throws {
        let httpbin = try TCPInternetSocket(
            scheme: "http",
            hostname: "httpbin.org",
            port: 80
        )
        let client = try TCPClient(httpbin, maxResponseSize: 100_000)
        let req = Request(method: .get, uri: "http://httpbin.org/bytes/8192")
        let res = try client.respond(to: req)
        XCTAssertEqual(res.body.bytes?.count, 8192)
        try httpbin.close()
    }

    func testBigFile() throws {
        // comment this out to boot a server for testing
        
        /* let localhost = try TCPInternetSocket(
            scheme: "http",
            hostname: "0.0.0.0",
            port: 8742
        )
        let server = try TCPServer(localhost)

        let bigFile = Bytes(repeating: .a, count: 20_000_000)
        let responder = BasicResponder { req in
            return Response(status: .ok, body: bigFile)
        }

        try server.start(responder) */
    }
    
    static var allTests = [
        ("testBufferParse", testBufferParse),
        ("testChunkedParse", testChunkedParse),
        ("testClientStreamUsage", testClientStreamUsage)
    ]
}
