import HTTPKit
import XCTest

class Utilities: XCTestCase {
    var eventLoopGroup: EventLoopGroup!
    
    override func setUp() {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 8)
    }
    
    override func tearDown() {
        try! self.eventLoopGroup.syncShutdownGracefully()
    }

    func testRFC1123Flip() throws {
        let nowStamp = Date().rfc1123
        let boundary = 1.0 - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1)
        Thread.sleep(forTimeInterval: boundary - 0.01)
        let beforeStamp = Date().rfc1123
        Thread.sleep(forTimeInterval: 0.02)
        let afterStamp = Date().rfc1123
        
        XCTAssertEqual(nowStamp, beforeStamp)
        XCTAssertNotEqual(beforeStamp, afterStamp)
    }
}
