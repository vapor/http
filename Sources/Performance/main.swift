import HTTP 

let server = DispatchAsyncServer()
// let server = DispatchSyncServer()
let responder = Request.Handler { req in
    return Response(status: .ok, body: "Hello world".makeBytes())
}
try server.start(responder) { error in
    print(error)
}
