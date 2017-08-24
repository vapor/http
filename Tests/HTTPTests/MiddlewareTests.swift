import Core
import Dispatch
import HTTP
import XCTest

class MiddlewareTests : XCTestCase {
    func testMiddleware() throws {
        let server = EmitterStream<Request>()

        let group = DispatchGroup()
        group.enter()
        let app = TestApp { req in
            XCTAssertEqual(req.headers["foo"], "bar")
            group.leave()
        }

        let middlewares = [TestMiddleware(), TestMiddleware()]
        let responder = middlewares.makeResponder(chainedto: app)

        let queue = DispatchQueue(label: "codes.vapor.http.test.middleware")

        group.enter()
        server.stream(to: responder.makeStream(on: queue)).drain { res in
            XCTAssertEqual(res.headers["baz"], "bar")
            group.leave()
        }

        let req = Request()
        server.emit(req)
        group.wait()
    }

    static let allTests = [
        ("testMiddleware", testMiddleware)
    ]
}

/// Test application that passes all incoming
/// requests through a closure for testing
final class TestApp: Responder {
    let closure: (Request) -> ()

    init(closure: @escaping (Request) -> ()) {
        self.closure = closure
    }

    func respond(to req: Request) throws -> Future<Response> {
        closure(req)
        let promise = Promise<Response>()
        
        promise.complete(Response())
        
        return promise.future
    }
}

/// Test middleware that sets req and res headers.
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

