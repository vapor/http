import XCTest
@testable import HTTP
import Transport
import libc
import SocksCore

class HTTPBodyTests: XCTestCase {
    static var allTests = [
        ("testBufferParse", testBufferParse),
        ("testChunkedParse", testChunkedParse),
        ("testClientStreamUsage", testClientStreamUsage),
//        ("testReleasingServer", testReleasingServer),
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
                return Response(body: "Hello".makeBytes())
            }
        }

        background {
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
                XCTAssertEqual(res.body.bytes ?? [], "Hello".makeBytes())
            }
        } catch {
            XCTFail("\(error)")
        }
        
        // WARNING: `server` will keep running in the background since there is no way to stop it. Its socket will continue to exist and the associated port will be in use until the xctest process exits.
    }

    func testClientStreamUsageAsync() throws {
#if os(Linux)
        let server = try HTTP.Server<TCPServerStream, Parser<Request>, Serializer<Response>>(host: "0.0.0.0", port: 0, securityLayer: .none)
        let assignedPort = try server.server.stream.localAddress().port

        struct HelloResponder: HTTP.Responder {
            func respond(to request: Request) throws -> Response {
                return Response(body: "Hello".makeBytes())
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
                XCTAssertEqual(res.body.bytes ?? [], "Hello".makeBytes())
            }
        } catch {
            XCTFail("\(error)")
        }
#endif
    } 
    
    
//    /**
//      Tests if `Server` is properly deallocated and its sockets closed
//      Not enabled because testing sometimes fails because sockets are not forcibly closed (shutdown?)
//    */
//    func testReleasingServer() throws {
//        typealias ServerType = HTTP.Server<TCPServerStream, Parser<Request>, Serializer<Response>>
//        let port = 8642
//        let socket = try TCPClientStream(host: "0.0.0.0", port: port).stream
//        var server:ServerType? = try ServerType(host: "0.0.0.0", port: port, securityLayer: .none)
//
//        struct HelloResponder: HTTP.Responder {
//            func respond(to request: Request) throws -> Response {
//                return Response(body: "Hello".makeBytes())
//            }
//        }
//        
//        try server?.startAsync(responder: HelloResponder(), errors: { err in
//            XCTFail("\(err)")
//        })
//        
//        let res = try HTTP.Client<TCPClientStream, Serializer<Request>, Parser<Response>>.get("http://0.0.0.0:\(port)/")
//        XCTAssertEqual(res.body.bytes ?? [], "Hello".makeBytes())
//        
//        _ = try socket.connect()
//        
//        try socket.send("Hello")
//
//        weak var weakServer = server
//        server = nil
//        // `Server` should be released
//        XCTAssertNil(weakServer)
//        
//        // existing connections should be unable to send data
//        do {
//            try socket.send("Hello again")
//            XCTFail("Expected to throw")
//        } catch let error as StreamError {
//            guard case StreamError.send(_, let socksError as SocksError) = error, case ErrorReason.sendFailedToSendAllBytes = socksError.type else {
//                XCTFail("Unexpected Error: \(error)")
//                return
//            }
//        }
//        try socket.close()
//        
//        // new connections should fail
//        do {
//            _ = try HTTP.Client<TCPClientStream, Serializer<Request>, Parser<Response>>.get("http://0.0.0.0:\(port)/")
//            XCTFail("Expected to throw")
//        } catch let error as SocksError {
//            guard case ErrorReason.connectFailed = error.type else {
//                XCTFail("Unexpected SocksError: \(error)")
//                return
//            }
//        }
//    }
}
