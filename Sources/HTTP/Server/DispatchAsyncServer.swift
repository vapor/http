import Transport
import libc
import Sockets
import Dispatch
import Random

private var res = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 13\r\n\r\nHello, world!".makeBytes()


class Queue {
    var queue: DispatchQueue
    var buffer: Bytes
    var id: Int
    
    init(id: Int, _ queue: DispatchQueue, _ buffer: Bytes) {
        self.id = id
        self.queue = queue
        self.buffer = buffer
    }
}

public final class DispatchAsyncServer: Server {
    public var scheme: String
    public var hostname: String
    public var port: Port
    
    var queues: [Queue] = []
    public init() {
        self.scheme = "http"
        self.hostname = "0.0.0.0"
        self.port = 8080
        for i in 1...4 {
            print("Creating queue \(i)")
            let queue = Queue(
                id: i,
                DispatchQueue(label: "codes.vapor.server.worker.\(i)"),
                Array<Byte>(repeating: 0, count: 4096)
            )
            queues.append(queue)
        }
    }
    
    var queue = DispatchQueue(label: "codes.vapor.server")

    public func start(_ responder: Responder, errors: @escaping ServerErrorHandler) throws {
        let listen = try TCPInternetSocket(port: self.port)
        try listen.bind()
        try listen.listen(max: 100)
        try self.run(listen)
    }
    
    public func run(_ listen: TCPInternetSocket) throws {
        let main = DispatchSource.makeReadSource(fileDescriptor: listen.descriptor.raw, queue: queue)
        
        var reads: [Int32: DispatchSourceRead] = [:]
        var writes: [Int32: DispatchSourceWrite] = [:]
        
        main.setEventHandler() {
            let client = accept(listen.descriptor.raw, nil, nil)
            guard let queue = self.queues.random else {
                return
            }
            print("Accepted \(client) on worker \(queue.id)")
            
            let write: DispatchSourceWrite
            if let existing = writes[client] {
                write = existing
            } else {
                let new = DispatchSource.makeWriteSource(fileDescriptor: client, queue: queue.queue)
                writes[client] = new
                
                new.setEventHandler {
                    // print("Writing data to \(client)")
                    let rc = send(client, &res, res.count, 0)
                    if (rc < 0)
                    {
                        perror("  send() failed");
                        return
                    }
                    new.suspend()
                }

                new.setCancelHandler {
                    // print("Write \(client) cancelled") 
                }

                write = new
            }
            
            let read: DispatchSourceRead
            if let existing = reads[client] {
                read = existing
            } else {
                let new = DispatchSource.makeReadSource(fileDescriptor: client, queue: queue.queue)
                reads[client] = new
                
                new.setEventHandler {
                    // print("Reading data from \(client)")
                    let rc = recv(client, &queue.buffer, queue.buffer.capacity, 0)
                    // print("Read \(rc) from \(client)")
                    if (rc < 0)
                    {
                        if (errno != EWOULDBLOCK)
                        {
                            perror("  recv() failed");
                            return
                        }
                    }
                    
                    
                    if (rc == 0)
                    {
                        print("\(client) closed");
                        close(client)
                        new.cancel()
                        write.cancel()
                        reads[client] = nil
                        writes[client] = nil
                        return
                    }
                    
                    
                    write.resume()
                }
                
                new.setCancelHandler {
                    // print("Read \(client) cancelled")
                }
                read = new
            }
            read.resume()

        }
        main.resume()
        
        // infinite wait
        let group = DispatchGroup()
        group.enter()
        group.wait()
    }
}
