import NetKit

let hostname = "127.0.0.1"
let elg = MultiThreadedEventLoopGroup(numberOfThreads: 8)

let client = HTTPClient(on: elg)

let res0 = client.get("http://httpbin.org/status/200")
let res1 = client.get("http://httpbin.org/status/201")
let res2 = client.get("http://httpbin.org/status/202")

try print(res0.wait().status)
try print(res1.wait().status)
try print(res2.wait().status)

let res = HTTPResponse(body: "pong" as StaticString)

struct EchoResponder: HTTPServerDelegate {
    func respond(to req: HTTPRequest, on channel: Channel) -> EventLoopFuture<HTTPResponse> {
        return channel.eventLoop.makeSucceededFuture(result: res)
    }
}
let responder = EchoResponder()

print("Plaintext server starting on http://\(hostname):8080")

let plaintextServer = HTTPServer(
    config: .init(
        hostname: hostname,
        port: 8080
    ),
    on: elg
)
try plaintextServer.start(delegate: responder).wait()


// Uncomment to start only plaintext server
// plaintextServer.onClose.wait()

print("TLS server starting on https://\(hostname):8443")

let tlsServer = HTTPServer(
    config: .init(
        hostname: hostname,
        port: 8443,
        tlsConfig: .forServer(
            certificateChain: [.file("/Users/tanner0101/dev/vapor/http/certs/cert.pem")],
            privateKey: .file("/Users/tanner0101/dev/vapor/http/certs/key.pem")
        )
    ),
    on: elg
)
try tlsServer.start(delegate: responder).wait()

_ = try plaintextServer.onClose
    .and(tlsServer.onClose).wait()

try elg.syncShutdownGracefully()
