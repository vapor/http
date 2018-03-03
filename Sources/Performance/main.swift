import Async
import HTTP
import Foundation

let hostname = "localhost"
let port: Int = 8123

struct EchoResponder: HTTPResponder {
    func respond(to req: HTTPRequest) -> Future<HTTPResponse> {
        return Future.map(on: req) { try HTTPResponse(body: "Hello, world!".makeBody(), on: req) }
    }
}

print("Server starting on http://\(hostname):\(port)")
let server = try HTTPServer.start(hostname: hostname, port: port, responder: EchoResponder()).wait()
try server.onClose.wait()
