import WebSocket
import Core
import Crypto
import Dispatch
import Foundation
import HTTP
import TCP

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

struct Application: Responder {
    func respond(to req: Request) throws -> Future<Response> {
        let res: Response

        if WebSocket.shouldUpgrade(for: req) {
            res = try WebSocket.upgradeResponse(for: req)
            res.onUpgrade = { client in
                let websocket = WebSocket(client: client)
                websocket.textStream.drain { text in
                    let rev = String(text.reversed())
                    websocket.textStream.inputStream(rev)
                }
            }
        } else {
            res = try Response(status: .ok, body: "hi")
        }

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
    let tcpClient = TCP.Client(socket: socket, queue: .global())

    let client = HTTP.Client(client: tcpClient)

    emitter.stream(to: serializer)
        .stream(to: client)
        .stream(to: parser)
        .drain { response in
            print(String(data: response.body.data, encoding: .utf8)!)
        }

    emitter.errorStream = { error in
        print(error)
    }
    tcpClient.start()


    let request = try Request(method: .get, uri: URI(path: "/"), body: "hello")
    request.headers[.host] = "google.com"
    request.headers[.userAgent] = "vapor/engine"

    emitter.emit(request)
}

// MARK: Server
do {
    let app = Application()
    let tcpServer = try TCP.Server()
    let server = HTTP.Server(server: tcpServer)

    server.drain { client in
        let parser = HTTP.RequestParser()
        let serializer = HTTP.ResponseSerializer()

        client.stream(to: parser)
            .stream(to: app.makeStream(on: client.client.queue))
            .stream(to: serializer)
            .drain(into: client)

        client.client.start()
    }

    server.errorStream = { error in
        debugPrint(error)
    }

    try tcpServer.start(port: 8080)
    print("Server started...")
}


let group = DispatchGroup()
group.enter()
group.wait()
