import HTTP

let hostname = "127.0.0.1"

struct EchoResponder: HTTPServerDelegate {
    func respond(to req: HTTPRequest, on channel: Channel) -> EventLoopFuture<HTTPResponse> {
        let promise = channel.eventLoop.makePromise(of: HTTPResponse.self)
        channel.eventLoop.scheduleTask(in: .seconds(1)) {
            let res = HTTPResponse(body: "pong" as StaticString)
            promise.succeed(result: res)
        }
        return promise.futureResult
    }
}

print("Plaintext server starting on http://\(hostname):8080")

let plaintextServer = try HTTPServer.start(
    config: .init(hostname: hostname, port: 8080),
    delegate: EchoResponder()
).wait()

// Uncomment to start only plaintext server
// plaintextServer.onClose.wait()

print("TLS server starting on https://\(hostname):8443")

let tlsServer = try HTTPServer.start(
    config: .init(
        hostname: hostname,
        port: 8443,
        tlsConfig: .forServer(
            certificateChain: [.file("/Users/tanner0101/dev/vapor/http/certs/cert.pem")],
            privateKey: .file("/Users/tanner0101/dev/vapor/http/certs/key.pem")
        )
    ),
    delegate: EchoResponder()
).wait()

_ = try plaintextServer.onClose
    .and(tlsServer.onClose).wait()
