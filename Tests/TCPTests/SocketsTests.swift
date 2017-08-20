import TCP
import XCTest

class SocketsTests : XCTestCase {
    func testClient() throws {
        let socket = try! Socket()
        try! socket.connect(hostname: "google.com")

        let data = """
        GET / HTTP/1.1\r
        Host: google.com\r
        Content-Length: 2\r
        \r
        hi
        """.data(using: .utf8)!

        let group = DispatchGroup()

        let write = socket.onWriteable {
            try! socket.write(data)
        }

        group.enter()
        let read = socket.onReadable {
            let response = try! socket.read(max: 65_536)

            let string = String(data: response, encoding: .utf8)
            print(string)
            group.leave()
        }


        group.wait()
    }

    static let allTests = [
        ("testClient", testClient)
    ]
}
