import Core
import HTTP
import XCTest

class MiddlewareTests : XCTestCase {
    func testMiddleware() throws {
        let server = EmitterStream<Request>()

        let app = TestApp()
        let middlewares = [TestMiddleware(), TestMiddleware()]
        let responder = middlewares.makeResponder(chainedto: app)

        let queue = DispatchQueue(label: "codes.vapor.http.test.middleware")

        server.stream(to: responder.makeStream(on: queue)).drain { response in
            print(response.headers)
        }

        let req = Request()
        server.emit(req)
    }

    static let allTests = [
        ("testMiddleware", testMiddleware)
    ]
}

final class TestApp: Responder {
    func respond(to req: Request) throws -> Future<Response> {
        print(req.headers)
        return Future { Response() }
    }
}

final class TestMiddleware: Middleware {
    func respond(to request: Request, chainingTo next: Responder) throws -> Future<Response> {
        request.headers["foo"] = "bar"

        let promise = Promise<Response>()

        try next.respond(to: request).then { res in
            res.headers["baz"] = "bar"
            try! promise.complete(res)
        }

        return promise.future
    }
}

