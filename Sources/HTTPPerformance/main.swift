import HTTP

let hostname = "127.0.0.1"

struct EchoResponder: HTTPResponder {
    func respond(to req: HTTPRequest) -> EventLoopFuture<HTTPResponse> {
        let res = HTTPResponse(body: "pong" as StaticString)
        return req.channel!.eventLoop.makeSucceededFuture(result: res)
    }
}

print("Plaintext server starting on http://\(hostname):8080")

let plaintextServer = try HTTPServer.start(
    config: .init(hostname: hostname, port: 8080),
    responder: EchoResponder()
).wait()

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
    responder: EchoResponder()
).wait()

_ = try plaintextServer.onClose
    .and(tlsServer.onClose).wait()
