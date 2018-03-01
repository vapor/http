import Async
import HTTP

let hostname = "localhost"
let port: Int = 8123

struct EchoResponder: HTTPResponder {
    func respond(to req: HTTPRequest) -> Future<HTTPResponse> {
        return Future.map(on: req) { try HTTPResponse(body: "Hello, world!".makeBody(), on: req) }
    }
}

let server = HTTPServer(responder: EchoResponder())
print("Server starting on http://\(hostname):\(port)")
try server.start(hostname: hostname, port: port).wait()
