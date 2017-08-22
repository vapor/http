import WebSocket
import Core
import Dispatch
import Foundation
import HTTP
import TCP

extension String: Swift.Error { }

struct User: Codable {
    var name: String
    var age: Int
}

extension User: ContentCodable {
    static func decodeContent(from message: Message) throws -> User? {
        guard message.mediaType == .json else {
            throw "only json supported"
        }

        return try JSONDecoder().decode(User.self, from: message.body.data)
    }

    func encodeContent(to message: Message) throws {
        message.mediaType = .json
        message.body = try Body(JSONEncoder().encode(self))
    }

}

let res = try Response(status: .ok, body: "hi")

struct Application: Responder {
    func respond(to req: Request) throws -> Future<ResponseRepresentable> {
        // let user = User(name: "Vapor", age: 2)
        // print(String(cString: __dispatch_queue_get_label(nil), encoding: .utf8))
        // try! res.content(user)
        return Future { res }
    }
}


// MARK: Client
do {
    final class RequestEmitter: Core.OutputStream {
        typealias Output = Request
        var outputStream: OutputHandler?
        var errorStream: ErrorHandler?

        init() {}

        func emit(_ request: Request) {
            outputStream?(request)
        }
    }

    let emitter = RequestEmitter()
    let serializer = RequestSerializer()
    let parser = ResponseParser()

    let socket = try TCP.Socket()
    try socket.connect(hostname: "google.com", port: 80)
    let client = TCP.Client(socket: socket, queue: .global())

    emitter.stream(to: serializer)
        .stream(to: client)
        .stream(to: parser)
        .drain { response in
            print(String(data: response.body.data, encoding: .utf8)!)
        }

    emitter.errorStream = { error in
        print(error)
    }
    client.start()


    let request = try Request(method: .get, uri: URI(path: "/"), body: "hello")
    request.headers[.host] = "google.com"
    request.headers[.userAgent] = "vapor/engine"

    emitter.emit(request)
}

// MARK: Server
do {
    let app = Application()
    let server = try TCP.Server()

    server.drain { client in
        let parser = HTTP.RequestParser()
        let serializer = HTTP.ResponseSerializer()
        let websocketMiddleware = WebSocketMiddleware(client: client)
        
        websocketMiddleware.onConnect { websocket in
            websocket.textStream.drain { string in
                print(string)
                websocket.textStream.inputStream(string)
            }
        }

        client.stream(to: parser)
            .stream(to: websocketMiddleware)
            .stream(to: app.makeStream(on: client.queue))
            .stream(to: serializer)
            .drain(into: client)

        client.start()
    }

    server.errorStream = { error in
        debugPrint(error)
    }

    try server.start(port: 8080)
    print("Server started...")
}


let group = DispatchGroup()
group.enter()
group.wait()
