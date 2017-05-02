import Transport
import libc
import Sockets
import Dispatch
import Random

class Worker {
    var id: Int
    var queue: DispatchQueue
    var buffer: Bytes
    
    let serializer: BytesResponseSerializer
    let parser: RequestParser
    let responder: Responder
    
    init(id: Int, _ responder: Responder) {
        self.id = id
        self.responder = responder
        
        self.queue = DispatchQueue(label: "codes.vapor.server.worker.\(id)")
        self.buffer = Bytes(repeating: 0, count: 4096)
        self.serializer = BytesResponseSerializer()
        self.parser = RequestParser()
    }
    
    func onDataAvailable(
        _ readQueue: DispatchSourceRead,
        _ client: TCPInternetSocket
    ) throws {
        let rc = recv(client.descriptor.raw, &buffer, buffer.capacity, 0)
        
        if (rc < 0) {
            _ = libc.close(client.descriptor.raw)
            readQueue.cancel()
            return
        }
        
        if (rc == 0) {
            _ = libc.close(client.descriptor.raw)
            readQueue.cancel()
            return
        }
        
        guard let request = try parser.parse(from: &buffer, length: rc) else {
            print("no request yet")
            // will try again when more data is available
            return
        }
        
        try responder.respond(to: request) { response in
            var length = 1
            while length > 0 {
                length = try self.serializer.serialize(response, into: &self.buffer)
                if length > 0 {
                    let rc = send(client.descriptor.raw, &self.buffer, length, 0)
                    if (rc < 0) {
                        perror("  send() failed");
                        return
                    }
                }
            }
        }
    }
}

public final class AsyncServer {
    public var scheme: String
    public var hostname: String
    public var port: Port
    var workers: [Worker]
    
    public init(scheme: String, hostname: String, port: Port) {
        self.scheme = scheme
        self.hostname = hostname
        self.port = port
        self.workers = []
    }
    

    public func start(_ responder: Responder, errors: @escaping ServerErrorHandler) throws {
        let listen = try TCPInternetSocket(port: self.port)
        try listen.bind()
        try listen.listen(max: 100)
    
        for i in 1...4 {
            print("Creating worker \(i)")
            let worker = Worker(id: i, responder)
            workers.append(worker)
        }
        
        try self.run(listen)
    }
    
    public func run(_ server: TCPInternetSocket) throws {
        let queue = DispatchQueue(label: "codes.vapor.server")
        let main = DispatchSource.makeReadSource(
            fileDescriptor: server.descriptor.raw,
            queue: queue
        )
        
        main.setEventHandler() {
            let client = try! server.accept()
            guard let queue = self.workers.random else {
                print("Could not find a random worker")
                return
            }

            let read = DispatchSource.makeReadSource(
                fileDescriptor: client.descriptor.raw,
                queue: queue.queue
            )
            
            read.setEventHandler {
                try! queue.onDataAvailable(read, client)
            }
            
            read.setCancelHandler {}
            read.resume()
        }
        
        main.resume()
        
        let semaphore = DispatchSemaphore(value: 0)
        semaphore.wait()
    }
}
