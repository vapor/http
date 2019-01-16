import HTTP

let hostname = "127.0.0.1"

do {
    let client = try HTTPClient.connect(config: .init(hostname: "httpbin.org")).wait()
    
    let res0 = client.send(.init(url: "/status/200"))
    let res1 = client.send(.init(url: "/status/201"))
    let res2 = client.send(.init(url: "/status/202"))
    
    try print(res0.wait())
    try print(res1.wait())
    try print(res2.wait())
}

let res = HTTPResponse(body: "pong" as StaticString)

struct EchoResponder: HTTPServerDelegate {
    func respond(to req: HTTPRequest, on channel: Channel) -> EventLoopFuture<HTTPResponse> {
        return channel.eventLoop.makeSucceededFuture(result: res)
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
