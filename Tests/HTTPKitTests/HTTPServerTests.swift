import HTTPKit
import XCTest

class HTTPServerTests: XCTestCase {
    func testLargeResponseClose() throws {
        struct LargeResponder: HTTPServerDelegate {
            func respond(to request: HTTPRequest, on channel: Channel) -> EventLoopFuture<HTTPResponse> {
                let res = HTTPResponse(
                    status: .ok,
                    body: String(repeating: "0", count: 2_000_000)
                )
                return channel.eventLoop.makeSucceededFuture(res)
            }
        }
        let server = HTTPServer(
            config: .init(
                hostname: "localhost",
                port: 8080,
                supportVersions: [.one],
                errorHandler: { error in
                    XCTFail("\(error)")
                }
            ),
            on: self.eventLoopGroup
        )
        try server.start(delegate: LargeResponder()).wait()
    
        var req = HTTPRequest(method: .GET, url: "http://localhost:8080/")
        req.headers.replaceOrAdd(name: .connection, value: "close")
        let res = try HTTPClient(on: self.eventLoopGroup)
            .send(req).wait()
        XCTAssertEqual(res.body.count, 2_000_000)
        try server.shutdown().wait()
        try server.onClose.wait()
    }
    
    func testRFC1123Flip() throws {
        var now: Date?
        var boundary = 0.0
        while boundary <= 0.01 {
            now = Date()
            boundary = 1.0 - now!.timeIntervalSince1970.truncatingRemainder(dividingBy: 1)
        }
        let nowStamp = now!.rfc1123
        Thread.sleep(forTimeInterval: boundary - 0.01)
        let beforeStamp = Date().rfc1123
        Thread.sleep(forTimeInterval: 0.02)
        let afterStamp = Date().rfc1123
        
        XCTAssertEqual(nowStamp, beforeStamp)
        XCTAssertNotEqual(beforeStamp, afterStamp)
    }
    
    var eventLoopGroup: EventLoopGroup!
    
    override func setUp() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }
    
    override func tearDown() {
        try! self.eventLoopGroup.syncShutdownGracefully()
    }
}
