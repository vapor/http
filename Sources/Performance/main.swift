import HTTP

let server = DispatchAsyncServer()
// let server = DispatchSyncServer()

let responder = BasicResponder { req, writer in
    let res = Response(status: .ok, body: "Hello world: \(req.uri.path)".makeBytes())
    try writer.write(res)
}

try server.start(responder) { error in
    print(error)
}
