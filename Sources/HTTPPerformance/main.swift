import HTTP
import NIO

let hostname = "127.0.0.1"
let port: Int = 8123

let res = HTTPResponse(body: "pong" as StaticString)

struct EchoResponder: HTTPServerResponder {
    func respond(to request: HTTPRequest, on channel: Channel) -> EventLoopFuture<HTTPResponse> {
        return channel.eventLoop.makeSucceededFuture(result: res)
    }
}

print("Server starting on http://\(hostname):\(port)")
let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
defer { try! group.syncShutdownGracefully() }

let server = try HTTPServer.start(hostname: hostname, port: port, responder: EchoResponder(), on: group).wait()
try server.onClose.wait()
