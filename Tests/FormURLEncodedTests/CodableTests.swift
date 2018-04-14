import FormURLEncoded
import HTTP
import XCTest

class FormURLEncodedCodableTests: XCTestCase {
    func testDecode() throws {
        let data = """
        name=Tanner&age=23&pets[]=Zizek&pets[]=Foo&dict[a]=1&dict[b]=2
        """.data(using: .utf8)!

        let user = try FormURLDecoder().decode(User.self, from: data)
        XCTAssertEqual(user.name, "Tanner")
        XCTAssertEqual(user.age, 23)
        XCTAssertEqual(user.pets.count, 2)
        XCTAssertEqual(user.pets.first, "Zizek")
        XCTAssertEqual(user.pets.last, "Foo")
        XCTAssertEqual(user.dict["a"], 1)
        XCTAssertEqual(user.dict["b"], 2)
    }

    func testDecodeMessage() throws {
        let data = """
        name=Tanner&age=23&pets[]=Zizek&pets[]=Foo&dict[a]=1&dict[b]=2
        """.data(using: .utf8)!
        let request = HTTPRequest(headers: ["Content-Type": "application/x-www-form-urlencoded"], body: HTTPBody(data: data))
        let user = try FormURLDecoder().decode(User.self, from: request, maxSize: Int.max, on: EmbeddedEventLoop()).wait()
        XCTAssertEqual(user.name, "Tanner")
    }

    func testEncode() throws {
        let user = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2])
        var res = HTTPResponse(status: .ok)
        try FormURLEncoder().encode(user, to: &res, on: EmbeddedEventLoop())
        let data = res.body.data!
        let result = String(data: data, encoding: .utf8)!
        XCTAssert(result.contains("pets[]=Zizek"))
        XCTAssert(result.contains("pets[]=Foo"))
        XCTAssert(result.contains("age=23"))
        XCTAssert(result.contains("name=Tanner"))
        XCTAssert(result.contains("dict[a]=1"))
        XCTAssert(result.contains("dict[b]=2"))
    }

    func testCodable() throws {
        let a = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2])
        let body = try FormURLEncoder().encode(a)
        let b = try FormURLDecoder().decode(User.self, from: body)
        XCTAssertEqual(a, b)
    }

    func testDecodeIntArray() throws {
        let data = """
        array[]=1&array[]=2&array[]=3
        """.data(using: .utf8)!

        let content = try FormURLDecoder().decode([String: [Int]].self, from: data)
        XCTAssertEqual(content["array"], [1, 2, 3])
    }

    static let allTests = [
        ("testDecode", testDecode),
        ("testDecodeMessage", testDecodeMessage),
        ("testEncode", testEncode),
        ("testCodable", testCodable),
        ("testDecodeIntArray", testDecodeIntArray),
    ]
}

struct User: Codable, Equatable {
    static func ==(lhs: User, rhs: User) -> Bool {
        return lhs.name == rhs.name
            && lhs.age == rhs.age
            && lhs.pets == rhs.pets
            && lhs.dict == rhs.dict
    }

    var name: String
    var age: Int
    var pets: [String]
    var dict: [String: Int]
}
