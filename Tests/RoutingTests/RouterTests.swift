import Async
import Dispatch
import HTTP
import Bits
import Routing
import Service
import XCTest

class RouterTests: XCTestCase {
    func testRouter() throws {
        let router = TrieRouter<Int>()

        let path: [PathComponent.Parameter] = [.string("foo"), .string("bar"), .string("baz")]

        let route = Route<Int>(path: [.constants(path), .parameter(.string(User.uniqueSlug))], output: 42)
        router.register(route: route)

        let container = try BasicContainer(
            config: Config(),
            environment: .development,
            services: Services(),
            on: DefaultEventLoop(label: "unit-test")
        )
        let params = Params()
        XCTAssertEqual(router.route(path: path + [.string("Tanner")], parameters: params), 42)
        try XCTAssertEqual(params.parameter(User.self, using: container).blockingAwait().name, "Tanner")
    }

    func testAnyRouting() throws {
        let router = TrieRouter<Int>()
        
        let route0 = Route<Int>(path: [
            .constants([.string("a")]),
            .anything
        ], output: 0)
        
        let route1 = Route<Int>(path: [
            .constants([.string("b")]),
            .parameter(.string("1")),
            .anything
        ], output: 1)
        
        let route2 = Route<Int>(path: [
            .constants([.string("c")]),
            .parameter(.string("1")),
            .parameter(.string("2")),
            .anything
        ], output: 2)
        
        let route3 = Route<Int>(path: [
            .constants([.string("d")]),
            .parameter(.string("1")),
            .parameter(.string("2")),
        ], output: 3)
        
        let route4 = Route<Int>(path: [
            .constants([.string("e")]),
            .parameter(.string("1")),
            .anything,
            .constants([.string("a")])
        ], output: 4)
        
        router.register(route: route0)
        router.register(route: route1)
        router.register(route: route2)
        router.register(route: route3)
        router.register(route: route4)
        
        XCTAssertEqual(
            router.route(path: [.string("a"), .string("b")], parameters: Params()),
            0
        )
        
        XCTAssertNil(router.route(path: [.string("a")], parameters: Params()))
        
        XCTAssertEqual(
            router.route(path: [.string("a"), .string("a")], parameters: Params()),
            0
        )
        
        XCTAssertEqual(
            router.route(path: [.string("b"), .string("a"), .string("c")], parameters: Params()),
            1
        )
        
        XCTAssertNil(router.route(path: [.string("b")], parameters: Params()))
        XCTAssertNil(router.route(path: [.string("b"), .string("a")], parameters: Params()))
        
        XCTAssertEqual(
            router.route(path: [.string("b"), .string("a"), .string("c")], parameters: Params()),
            1
        )
        
        XCTAssertNil(router.route(path: [.string("c")], parameters: Params()))
        XCTAssertNil(router.route(path: [.string("c"), .string("a")], parameters: Params()))
        XCTAssertNil(router.route(path: [.string("c"), .string("b")], parameters: Params()))
        
        XCTAssertEqual(
            router.route(path: [.string("d"), .string("a"), .string("b")], parameters: Params()),
            3
        )
        
        XCTAssertNil(router.route(path: [.string("d"), .string("a"), .string("b"), .string("c")], parameters: Params()))
        XCTAssertNil(router.route(path: [.string("d"), .string("a")], parameters: Params()))
        
        XCTAssertEqual(
            router.route(path: [.string("e"), .string("a"), .string("b"), .string("a")], parameters: Params()),
            4
        )
    }

    static let allTests = [
        ("testRouter", testRouter),
        ("testAnyRouting", testAnyRouting),
    ]
}

final class Params: ParameterContainer {
    var parameters: Parameters = []
    init() {}
}

final class User: Parameter {
    var name: String

    init(name: String) {
        self.name = name
    }

    static func make(for parameter: String, using container: Container) throws -> Future<User> {
        return Future(User(name: parameter))
    }
}
