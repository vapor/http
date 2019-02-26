import HTTPKit
import XCTest

class HTTPKitTestCase: XCTestCase {
    var eventLoopGroup: EventLoopGroup!
    
    func testClientDefaultConfig() throws {
        let client = HTTPClient(on: self.eventLoopGroup)
        let res = try client.get("https://vapor.codes").wait()
        XCTAssertEqual(res.status, .ok)
    }
    
    override func setUp() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 8)
    }
    
    override func tearDown() {
        try! self.eventLoopGroup.syncShutdownGracefully()
    }
}
