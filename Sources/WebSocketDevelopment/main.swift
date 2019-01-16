import WebSocket

let hostname = "127.0.0.1"

//let req = try HTTPRequest.webSocketUpgrade(method: .GET, url: "/", headers: [
//    "Host": "echo.websocket.org"
//]) { ws in
//    ws.onText { ws, text in
//        print(text)
//    }
//    ws.send(text: "Hello, world!")
//}
//let client = try HTTPClient.connect(config: .init(hostname: "echo.websocket.org")).wait()
//let res = try client.send(req).wait()
//print(res)

struct EchoResponder: HTTPServerDelegate {
    func respond(to req: HTTPRequest, on channel: Channel) -> EventLoopFuture<HTTPResponse> {
        do {
            let res = try HTTPResponse.webSocketUpgrade(for: req) { ws in
                ws.onText { ws, text in
                    ws.send(text: text.reversed())
                }
            }
            return channel.eventLoop.makeSucceededFuture(result: res)
        } catch {
            return channel.eventLoop.makeFailedFuture(error: error)
        }
    }
}

print("WebSocket server starting on ws://\(hostname):8080")

let server = try HTTPServer.start(
    config: .init(hostname: hostname, port: 8080),
    delegate: EchoResponder()
).wait()

try server.onClose.wait()
