import HTTP
import WebSockets

func webSocketClient(to url: String) throws {
    try WebSocket.connect(to: url) { ws in
        print("[ws connected]")

        ws.onText = { ws, text in
            print("[ws text] \(text)")
        }

        ws.onClose = { _, code, reason, clean in
            print("[ws close] \(clean ? "clean" : "dirty") \(code?.description ?? "") \(reason ?? "")")
        }
    }
}

func webSocketServer() throws {
    final class Responder: HTTP.Responder {
        func respond(to request: Request) throws -> Response {
            return try request.upgradeToWebSocket { ws in
                print("[ws connected]")

                ws.onText = { ws, text in
                    print("[ws text] \(text)")
                    try ws.send("🎙 \(text)")
                }

                ws.onClose = { _, code, reason, clean in
                    print("[ws close] \(clean ? "clean" : "dirty") \(code?.description ?? "") \(reason ?? "")")
                }
            }
        }
    }

    let server = try Server<TCPServerStream, Parser<Request>, Serializer<Response>>(port: port)

    print("Connect websocket to http://localhost:\(port)/")
    try server.start(responder: Responder()) { error in
        print("Got server error: \(error)")
    }
}

try webSocketServer()
