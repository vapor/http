import Core
import Dispatch
import HTTP
import Sockets
import XCTest

#if Xcode

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
        let server = try Server(port: 8080)

        server.then { client in
            let parser = RequestParser()

            client.map(parser.parse).map { request in
                return Response(status: 200)
            }.then(client.send)

            client.listen()
        }

//        #if Xcode
//        try server.start()
//
//        let group = DispatchGroup()
//        group.enter()
//        group.wait()
//        #endif
    }
}

#endif
