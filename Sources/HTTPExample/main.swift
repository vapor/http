import HTTP
import Transport

func client() throws {
    let response = try Client<TCPClientStream>.get("http://pokeapi.co/api/v2/pokemon/")
    print(response)
}

func server() throws {
    final class Responder: HTTP.Responder {
        func respond(to request: Request) throws -> Response {
            return Response(body: "Hello World")
        }
    }

    let server = try Server<TCPServerStream, Parser<Request>, Serializer<Response>>(port: port)

    print("visit http://localhost:\(port)/")
    try server.start(responder: Responder()) { error in
        print("Got error: \(error)")
    }
}

try server()
