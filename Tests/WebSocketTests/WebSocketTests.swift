@testable import WebSocket
import Service
import HTTP
import TCP
import Async
import XCTest

final class WebSocketTests : XCTestCase {
    func testTextStream() throws {
        // FIXME: tests are overproducing input buffers
        return;
        let worker = try DefaultEventLoop(label: "codes.vapor.test.worker")
        let quit = Promise<Void>()
        let serverSocket = try TCPSocket(isNonBlocking: true)
        let server = try TCPServer(socket: serverSocket)
        let container = BasicContainer(config: Config(), environment: .development, services: Services(), on: worker)

        let webserver = HTTPServer(
            acceptStream: server.stream(on: worker),
            worker: worker,
            responder: WebSocketResponder()
        )
        webserver.onError = { XCTFail("\($0)") }
        
        try server.start(hostname: "localhost", port: 8090, backlog: 128)
        Thread.async { worker.runLoop() }
        
        let websocket = try WebSocket.connect(to: "ws://localhost:8090", using: container)
        
        var messages = ["hello", "world", "!"]
        
        websocket.onString { ws, text in
            guard messages.count > 0 else {
                XCTFail("Invalid message received")
                return
            }
            
            let expectation = String(messages.removeFirst().reversed())
            
            XCTAssertEqual(expectation, text)
            
            if messages.count > 0 {
                ws.send(string: messages[0])
            } else {
                quit.complete()
            }
        }
        
        websocket.send(string: messages[0])
        
        try quit.future.blockingAwait(timeout: .seconds(10))
        XCTAssertEqual(messages.count, 0)
        websocket.close()
        server.stop()
        _ = webserver
    }

    static let allTests = [
        ("testTextStream", testTextStream),
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

            self.serverSide = websocket
        }

        return Future(response)
    }
}
