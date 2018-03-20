import FormURLEncoded
import HTTP
import XCTest

class FormURLEncodedCodableTests: XCTestCase {
    func testDecode() throws {
        let data = """
        name=Tanner&age=23&pets[]=Zizek&pets[]=Foo&dict[a]=1&dict[b]=2
        """.data(using: .utf8)!

        let user = try FormURLDecoder().decode(User.self, from: HTTPBody(data: data), on: EmbeddedEventLoop()).wait()
        XCTAssertEqual(user.name, "Tanner")
        XCTAssertEqual(user.age, 23)
        XCTAssertEqual(user.pets.count, 2)
        XCTAssertEqual(user.pets.first, "Zizek")
        XCTAssertEqual(user.pets.last, "Foo")
        XCTAssertEqual(user.dict["a"], 1)
        XCTAssertEqual(user.dict["b"], 2)
    }

    func testEncode() throws {
        let user = User(name: "Tanner", age: 23, pets: ["Zizek", "Foo"], dict: ["a": 1, "b": 2])
        let data = try FormURLEncoder().encodeBody(from: user).data!
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
        let body = try FormURLEncoder().encodeBody(from: a)
        let b = try FormURLDecoder().decode(User.self, from: body, on: EmbeddedEventLoop()).wait()
        XCTAssertEqual(a, b)
    }

    func testDecodeIntArray() throws {
        let data = """
        array[]=1&array[]=2&array[]=3
        """.data(using: .utf8)!

        let content = try FormURLDecoder().decode([String: [Int]].self, from: HTTPBody(data: data), on: EmbeddedEventLoop()).wait()
        XCTAssertEqual(content["array"], [1, 2, 3])
    }

    static let allTests = [
        ("testDecode", testDecode),
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
