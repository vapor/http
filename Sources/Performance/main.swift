import Async
import HTTP
import Foundation

let hostname = "localhost"
let port: Int = 8123

struct EchoResponder: HTTPResponder {
    func respond(to req: HTTPRequest, on worker: Worker) -> Future<HTTPResponse> {
        let res = HTTPResponse(body: HTTPBody(string: "Hello, world!"))
        return Future.map(on: worker) { res }
    }
}

print("Server starting on http://\(hostname):\(port)")
let group = MultiThreadedEventLoopGroup(numThreads: 1)
let server = try HTTPServer.start(hostname: hostname, port: port, responder: EchoResponder(), on: group).wait()
try server.onClose.wait()
