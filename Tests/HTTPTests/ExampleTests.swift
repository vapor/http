@testable import HTTP
import Sockets
import Streams
import XCTest

class ExampleTests : XCTestCase {
//    Running 5s test @ http://localhost:8080/
//    2 threads and 10 connections
//    Thread Stats   Avg      Stdev     Max   +/- Stdev
//    Latency    86.80us   25.33us   1.68ms   92.99%
//    Req/Sec    53.43k     0.99k   55.42k    72.55%
//    542210 requests in 5.10s, 19.65MB read
//    Requests/sec: 106308.54
//    Transfer/sec:      3.85MB
    func testExample() throws {
        let server = try ServerSocket(port: 8080)

        server.onConnect = { client in
            let parser = RequestParser()
            
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
