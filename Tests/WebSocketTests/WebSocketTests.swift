@testable import WebSocket
import Service
import HTTP
import TCP
import Async
import XCTest

final class WebSocketTests : XCTestCase {
    static let allTests = [
        ("testTextStream", testTextStream),
    ]
    
    let worker = DispatchEventLoop(label: "codes.vapor.test.worker.1")
    let clientLoop = DispatchEventLoop(label: "codes.vapor.test.client")
    let serverLoop = DispatchEventLoop(label: "codes.vapor.test.server")
    
    func testTextStream() throws {
        let quit = Promise<Void>()
        
        let serverSocket = try TCPSocket(isNonBlocking: true)
        let server = try TCPServer(socket: serverSocket)
        
        let container = BasicContainer(config: Config(), environment: .development, services: Services(), on: clientLoop)
        
        final class WebSocketResponder: HTTPResponder, Worker {
            var eventLoop: EventLoop
            var serverSide: WebSocket?
            
            init(worker: Worker) {
                self.eventLoop = worker.eventLoop
            }
            
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
        
        let responders = [
            WebSocketResponder(worker: worker),
        ]
        
        let webserver = HTTPServer(acceptStream: server.stream(on: serverLoop), workers: responders)
        webserver.onError = { XCTFail("\($0)") }
        
        try server.start(hostname: "localhost", port: 8090, backlog: 128)
        
        if #available(OSX 10.12, *) {
            Thread.detachNewThread {
                self.serverLoop.run()
            }
            Thread.detachNewThread {
                self.worker.run()
            }
            Thread.detachNewThread {
                self.clientLoop.run()
            }
        } else {
            fatalError()
        }
        
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
}
