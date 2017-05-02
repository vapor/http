import Transport
import libc
import Sockets
import Dispatch

private var res = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 13\r\n\r\nHello, world!".makeBytes()

public final class DispatchSyncServer: Server {
    public var scheme: String
    public var hostname: String
    public var port: Port
    
    //    var queues: [Queue] = []
    public init() {
        self.scheme = "http"
        self.hostname = "0.0.0.0"
        self.port = 8080
        //        for i in 1...8 {
        //            print("Creating queue \(i)")
        //            let queue = Queue(
        //                DispatchQueue(label: "codes.vapor.server.worker.\(i)", qos: .userInteractive),
        //                Array<Byte>(repeating: 0, count: 4096)
        //            )
        //            queues.append(queue)
        //        }
    }
    
    var queue = DispatchQueue(label: "codes.vapor.server", qos: .userInteractive, attributes: .concurrent)
    
    public func start(_ responder: Responder, errors: @escaping ServerErrorHandler) throws {
        let listen = try TCPInternetSocket(port: self.port)
        try listen.bind()
        try listen.listen(max: 32)
        
        while true {
            let client = accept(listen.descriptor.raw, nil, nil)
            
            queue.async {
                while true {
                    
                    let serializer = BytesResponseSerializer()
                    let parser = RequestParser()
                    
                    var buffer = Array<Byte>(repeating: 0, count: 4096)
                    
                    var rc = recv(client, &buffer, buffer.capacity, 0)
                    if (rc < 0)
                    {
                        perror("  recv() failed");
                    }
                    
                    
                    if (rc == 0)
                    {
                        // print("  Connection closed\n");
                        close(client)
                        break
                    }
                    
                    guard let request = try! parser.parse(from: &buffer, length: rc) else {
                        print("no request yet")
                        return
                    }
    
                    let response = try! responder.respondSync(to: request)
                    let length = try! serializer.serialize(response, into: &buffer)
                    
                    // print("Writing data to \(client)")
                    rc = send(client, &buffer, length, 0)
                    if (rc < 0)
                    {
                        perror("  send() failed");
                        return
                    }
                }
            }
        }
    }
}
