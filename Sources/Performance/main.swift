import HTTP

let server = AsyncServer(
    scheme: "http",
    hostname: "0.0.0.0",
    port: 8080
)
// let server = DispatchSyncServer()

let responder = BasicResponder { req, writer in
    let res = Response(status: .ok, body: "Hello world: \(req.uri.path)".makeBytes())
    try writer.write(res)
}

try server.start(responder) { error in
    print(error)
}
