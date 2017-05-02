import Transport
import libc
import Sockets
import Dispatch
import Random

class Queue {
    var queue: DispatchQueue
    var buffer: Bytes
    var id: Int
    
    var client: Int32 = 0
    var read: DispatchSourceRead?
    var write: DispatchSourceWrite?
    
    let serializer: BytesResponseSerializer
    let parser: RequestParser
    let responder: Responder
    var writer: ResponseWriter?
    
    init(id: Int, _ responder: Responder) {
        self.id = id
        self.queue = DispatchQueue(label: "codes.vapor.server.worker.\(id)")
        self.buffer = Bytes(repeating: 0, count: 4096)
        self.serializer = BytesResponseSerializer()
        self.parser = RequestParser()
        self.responder = responder
        self.writer = BasicResponseWriter { response in
            // FIXME: what if buffer is too small?
            let length = try! self.serializer.serialize(response, into: &self.buffer)
            let rc = send(self.client, &self.buffer, length, 0)
            if (rc < 0) {
                perror("  send() failed");
                return
            }
        }
    }
    
    func onDataAvailable() throws {
        var rc = recv(client, &buffer, buffer.capacity, 0)
        
        if (rc < 0) {
            if (errno != EWOULDBLOCK)
            {
                perror("  recv() failed");
                _ = libc.close(client)
                read?.cancel()
                return
            }
        }
        
        if (rc == 0) {
            _ = libc.close(client)
            read?.cancel()
            return
        }
        
        guard let request = try parser.parse(from: &buffer, length: rc) else {
            print("no request yet")
            // will try again when more data is available
            return
        }
        
        try responder.respond(to: request, with: writer!)
    }
}

public final class DispatchAsyncServer {
    public var scheme: String
    public var hostname: String
    public var port: Port
    
    var queues: [Queue] = []
    public init() {
        self.scheme = "http"
        self.hostname = "0.0.0.0"
        self.port = 8080
    }
    
    var queue = DispatchQueue(label: "codes.vapor.server")

    public func start(_ responder: Responder, errors: @escaping ServerErrorHandler) throws {
        let listen = try TCPInternetSocket(port: self.port)
        try listen.bind()
        try listen.listen(max: 100)
    
        for i in 1...4 {
            print("Creating worker \(i)")
            let queue = Queue(id: i, responder)
            queues.append(queue)
        }
        
        try self.run(listen)
    }
    
    public func run(_ listen: TCPInternetSocket) throws {
        let main = DispatchSource.makeReadSource(fileDescriptor: listen.descriptor.raw, queue: queue)
        
        main.setEventHandler() {
            let client = accept(listen.descriptor.raw, nil, nil)
            guard let queue = self.queues.random else {
                print("Could not find queue")
                return
            }
            queue.client = client

            let read = DispatchSource.makeReadSource(fileDescriptor: client, queue: queue.queue)
            queue.read = read
            
            read.setEventHandler {
                try! queue.onDataAvailable()
            }
            
            read.setCancelHandler {}
            read.resume()
        }
        
        main.resume()
        
        // infinite wait
        let group = DispatchGroup()
        group.enter()
        group.wait()
    }
}
