@testable import HTTP
import Sockets
import Streams
import XCTest

class ExampleTests : XCTestCase {
//    Running 5s test @ http://localhost:8080/
//    2 threads and 10 connections
//    Thread Stats   Avg      Stdev     Max   +/- Stdev
//    Latency   117.85us   22.83us   1.41ms   93.59%
//    Req/Sec    41.91k     1.68k   43.82k    90.20%
//    425124 requests in 5.10s, 15.41MB read
//    Requests/sec:  83359.85
//    Transfer/sec:      3.02MB
    func testExample() throws {
        let server = try ServerSocket(port: 8080)

        server.onConnect = { client in
            let parser = HTTPParser()
            
            let requestStream = client.map(parser.parse)

            requestStream.map { request in
                return Response(status: 200)
            }.then(client.send)
            
            client.listen()
        }

        try server.start()

        while true {
            sleep(3600000)
        }
    }
}
