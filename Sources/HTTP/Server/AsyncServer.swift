import Transport
import libc
import Sockets
import Dispatch
import Random
import TLS

public typealias TCPAsyncServer = AsyncServer<TCPInternetSocket>
public typealias TLSAsyncServer = AsyncServer<TLS.InternetSocket>

public final class AsyncServer<
    StreamType: ServerStream & DescriptorRepresentable
> where StreamType.Client: DescriptorRepresentable {
    public let stream: StreamType
    
    public var scheme: String {
        return stream.scheme
    }
    
    public var hostname: String {
        return stream.hostname
    }
    
    public var port: Port {
        return stream.port
    }
    
    public let listenMax: Int
    
    public let workerCount: Int
    
    var workers: [AsyncServerWorker<StreamType.Client>]
    
    public init(
        _ stream: StreamType,
        workerCount: Int = 4,
        listenMax: Int = 128
    ) {
        self.stream = stream
        self.listenMax = listenMax
        self.workerCount = workerCount
        self.workers = []
    }

    public func start(_ responder: AsyncResponder, errors: @escaping ServerErrorHandler) throws {
        try stream.bind()
        try stream.listen(max: listenMax)
    
        for i in 1...workerCount {
            print("Creating worker \(i)")
            let worker = AsyncServerWorker<StreamType.Client>(
                id: i, responder
            )
            workers.append(worker)
        }
        
        let queue = DispatchQueue(label: "codes.vapor.server")
        let main = DispatchSource.makeReadSource(
            fileDescriptor: stream.makeDescriptor().raw,
            queue: queue
        )
        
        main.setEventHandler() {
            let client = try! self.stream.accept()
            guard let queue = self.workers.random else {
                print("Could not find a random worker")
                return
            }
            
            try! queue.accept(client)
        }
        
        main.resume()
        
        let semaphore = DispatchSemaphore(value: 0)
        semaphore.wait()
    }
}
