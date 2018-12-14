import HTTP

let hostname = "127.0.0.1"
let port: Int = 8123

struct EchoResponder: HTTPResponder {
    func respond(to req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse(body: "pong" as StaticString)
        return req.channel!.eventLoop.makeSucceededFuture(result: res)
    }
}

print("Server starting on http://\(hostname):\(port)")

let server = try HTTPServer.start(
    config: .init(hostname: hostname, port: port),
    responder: EchoResponder()
).wait()
try server.onClose.wait()
