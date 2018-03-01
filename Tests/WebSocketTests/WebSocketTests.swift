//@testable import WebSocket
//import HTTP
//import TCP
//import Async
//import XCTest
//
//final class WebSocketTests : XCTestCase {
//    func testTextStream() throws {
//        let worker = try DefaultEventLoop(label: "codes.vapor.test.worker")
//        let serverSocket = try TCPSocket(isNonBlocking: true)
//        let server = try TCPServer(socket: serverSocket)
//        
//        try server.start(hostname: "localhost", port: 8090, backlog: 128)
//        Thread.async {
//            let webserver = HTTPServer(
//                acceptStream: server.stream(on: worker).map(to: TCPSocketStream.self) {
//                    $0.socket.stream(on: worker) { _, error in
//                        XCTFail("\(error)")
//                    }
//                },
//                worker: worker,
//                responder: WebSocketResponder()
//            )
//            webserver.onError = { XCTFail("\($0)") }
//            worker.runLoop()
//        }
//
//        let clientSocket = try TCPSocket(isNonBlocking: false)
//        let client = try TCPClient(socket: clientSocket)
//        try client.connect(hostname: "localhost", port: 8090)
//        let write = Data("""
//        GET / HTTP/1.1\r
//        Connection: Upgrade\r
//        Upgrade: websocket\r
//        Sec-WebSocket-Key: yQWympdS3/3+7EXhPH+P/A==\r
//        Sec-WebSocket-Version: 13\r
//        Content-Length: 0\r
//        \r
//
//        """.utf8)
//        _ = try client.socket.write(write)
//        let read = try client.socket.read(max: 512)
//        let string = String(data: read, encoding: .utf8)
//        XCTAssertEqual(string, """
//        HTTP/1.1 101 Upgrade\r
//        Upgrade: websocket\r
//        Connection: Upgrade\r
//        Sec-WebSocket-Accept: U5ZWHrbsu7snP3DY1Q5P3e8AkOk=\r
//        Content-Length: 0\r
//        \r
//
//        """)
//
//        client.close()
//        server.stop()
//    }
//
//    static let allTests = [
//        ("testTextStream", testTextStream),
//    ]
//}
//
//final class WebSocketResponder: HTTPResponder {
//    var serverSide: WebSocket?
//
//    init() {}
//
//    func respond(to req: HTTPRequest, on worker: Worker) throws -> Future<HTTPResponse> {
//        let response = try WebSocket.upgradeResponse(for: req, with: WebSocketSettings()) { websocket in
//            websocket.onString { ws, text in
//                ws.send(string: String(text.reversed()))
//            }
//            
//            websocket.onError { ws, error in
//                XCTFail("\(error)")
//            }
//            
//            websocket.onClose { _, _ in
//                print("closed")
//            }
//
//            self.serverSide = websocket
//        }
//
//        return Future(response)
//    }
//}

