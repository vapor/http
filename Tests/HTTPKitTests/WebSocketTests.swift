import HTTPKit
import XCTest

class WebSocketTests: HTTPKitTestCase {
    func testClient() throws {
        // ws://echo.websocket.org
        let client = HTTPClient(on: self.eventLoopGroup)
        
        let message = "Hello, world!"
        let promise = self.eventLoopGroup.next().makePromise(of: String.self)
        
        var req = HTTPRequest(url: "ws://echo.websocket.org/")
        req.webSocketUpgrade { ws in
            ws.onText { ws, text in
                promise.succeed(text)
                ws.close(code: .normalClosure)
            }
            ws.send(text: message)
        }
        do {
            let res = try client.send(req).wait()
            XCTAssertEqual(res.status, .switchingProtocols)
        } catch {
            promise.fail(error)
        }
        try XCTAssertEqual(promise.futureResult.wait(), message)
    }

    func testClientTLS() throws {
        // wss://echo.websocket.org
        let client = HTTPClient(
            config: .init(
                tlsConfig: .forClient(certificateVerification: .none)
            ),
            on: self.eventLoopGroup
        )

        let message = "Hello, world!"
        let promise = self.eventLoopGroup.next().makePromise(of: String.self)
        
        var req = HTTPRequest(url: "wss://echo.websocket.org/")
        req.webSocketUpgrade { ws in
            ws.onText { ws, text in
                promise.succeed(text)
                ws.close(code: .normalClosure)
            }
            ws.send(text: message)
        }
        do {
            let res = try client.send(req).wait()
            XCTAssertEqual(res.status, .switchingProtocols)
        } catch {
            promise.fail(error)
        }
        try XCTAssertEqual(promise.futureResult.wait(), message)
    }

    func testServer() throws {
        let delegate = WebSocketServerDelegate { ws, req in
            ws.send(text: req.url.path)
            ws.onText { ws, string in
                ws.send(text: string.reversed())
                if string == "close" {
                    ws.close()
                }
            }
            ws.onBinary { ws, data in
                print("data: \(data)")
            }
            ws.onCloseCode { code in
                print("code: \(code)")
            }
            ws.onClose.whenSuccess {
                print("closed")
            }
        }
        let server = HTTPServer(
            config: .init(
                hostname: "127.0.0.1",
                port: 8888
            ),
            on: self.eventLoopGroup
        )
        try server.start(delegate: delegate).wait()
        try server.close().wait()
        // uncomment to test websocket server
        // try server.onClose.wait()
    }


    func testServerContinuation() throws {
        let promise = self.eventLoopGroup.next().makePromise(of: String.self)
        let delegate = WebSocketServerDelegate { ws, req in
            ws.onText { ws, text in
                promise.succeed(text)
            }
        }
        let server = HTTPServer(
            config: .init(
                hostname: "127.0.0.1",
                port: 8888
            ),
            on: self.eventLoopGroup
        )
        try server.start(delegate: delegate).wait()
        let client = HTTPClient(on: self.eventLoopGroup)
        var req = HTTPRequest(url: "ws://127.0.0.1:8888/")
        req.webSocketUpgrade { ws in
            ws.send(raw: Array("Hello, ".utf8), opcode: .text, fin: false)
            ws.send(raw: Array("world".utf8), opcode: .continuation, fin: false)
            ws.send(raw: Array("!".utf8), opcode: .continuation)
        }
        do {
            let res = try client.send(req).wait()
            XCTAssertEqual(res.status, .switchingProtocols)
        } catch {
            promise.fail(error)
        }
        try XCTAssertEqual(promise.futureResult.wait(), "Hello, world!")
        try server.close().wait()
    }
}

struct WebSocketServerDelegate: HTTPServerDelegate {
    let onUpgrade: (WebSocket, HTTPRequest) -> ()
    init(onUpgrade: @escaping (WebSocket, HTTPRequest) -> ()) {
        self.onUpgrade = onUpgrade
    }
    
    func respond(to req: HTTPRequest, on channel: Channel) -> EventLoopFuture<HTTPResponse> {
        guard req.isRequestingUpgrade(to: "websocket") else {
            return channel.eventLoop.makeFailedFuture(HTTPError(identifier: "upgrade"))
        }
        
        
        do {
            var res = HTTPResponse()
            try res.webSocketUpgrade(for: req) { ws in
                self.onUpgrade(ws, req)
            }
            return channel.eventLoop.makeSucceededFuture(res)
        } catch {
            return channel.eventLoop.makeFailedFuture(error)
        }
    }
}
