import Async
import Bits
import TCP
import TLS
import XCTest
#if os(Linux)
    import OpenSSL
#else
    import AppleTLS
#endif

class SSLTests: XCTestCase {
    func testClientBlocking() { do { try _testClientBlocking() } catch { XCTFail("\(error)") } }
    func _testClientBlocking() throws {
        let tcpSocket = try TCPSocket(isNonBlocking: false)
        let tcpClient = try TCPClient(socket: tcpSocket)
        let tlsSettings = TLSClientSettings()
        #if os(Linux)
            let tlsClient = try OpenSSLClient(tcp: tcpClient, using: tlsSettings)
        #else
            let tlsClient = try AppleTLSClient(tcp: tcpClient, using: tlsSettings)
        #endif
        try tlsClient.connect(hostname: "google.com", port: 443)
        try tlsClient.socket.prepareSocket()
        let req = "GET /robots.txt HTTP/1.1\r\nContent-Length: 0\r\nHost: www.google.com\r\nUser-Agent: hi\r\n\r\n".data(using: .utf8)!
        _ = try tlsClient.socket.write(from: req.withByteBuffer { $0 })
        var res = Data(count: 4096)
        _ = try tlsClient.socket.read(into: res.withMutableByteBuffer { $0 })
        print(String(data: res, encoding: .ascii)!)
    }

    func testClient() { do { try _testClient() } catch { XCTFail("\(error)") } }
    func _testClient() throws {
        let tcpSocket = try TCPSocket(isNonBlocking: true)
        let tcpClient = try TCPClient(socket: tcpSocket)
        let tlsSettings = TLSClientSettings()
        #if os(Linux)
            let tlsClient = try OpenSSLClient(tcp: tcpClient, using: tlsSettings)
        #else
            let tlsClient = try AppleTLSClient(tcp: tcpClient, using: tlsSettings)
        #endif
        try tlsClient.connect(hostname: "google.com", port: 443)

        let exp = expectation(description: "read data")

        let clientLoop = try DefaultEventLoop(label: "codes.vapor.tls.client")
        Thread.async { clientLoop.runLoop() }

        let tlsStream = tlsClient.socket.source(on: clientLoop)
        let tlsSink = tlsClient.socket.sink(on: clientLoop)

        tlsStream.drain { buffer, upstream in
            let res = Data(buffer)
            XCTAssertTrue(String(data: res, encoding: .utf8)!.contains("User-agent: *"))
            exp.fulfill()
        }.catch { err in
            XCTFail("\(err)")
        }.finally {
            // closed
        }.upstream!.request(count: 1)

        let source = PushStream<ByteBuffer>()
        source.output(to: tlsSink)

        let req = "GET /robots.txt HTTP/1.1\r\nContent-Length: 0\r\nHost: www.google.com\r\nUser-Agent: hi\r\n\r\n".data(using: .utf8)!
        source.push(req.withByteBuffer { $0 })

        waitForExpectations(timeout: 10)
    }

    static let allTests = [
        ("testClientBlocking", testClientBlocking),
        ("testClient", testClient)
    ]
}
