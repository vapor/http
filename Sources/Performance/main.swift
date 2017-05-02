import HTTP

let res = Response(status: .ok, body: "Hello, world!".makeBytes())

var buffer = Bytes(repeating: 0, count: 2)
let serializer = BytesResponseSerializer()

var full: Bytes = []

var length = 1
while length > 0 {
    length = try serializer.serialize(res, into: &buffer)
    if length > 0 {
        full += buffer
    }
}

print(full.makeString())

// let server = DispatchAsyncServer()
let server = DispatchSyncServer()

let responder = BasicResponder { req, writer in
    let res = Response(status: .ok, body: "Hello world: \(req.uri.path)".makeBytes())
    try writer.write(res)
}

try server.start(responder) { error in
    print(error)
}
