import Core
import Dispatch
import libc

/// A server socket can accept peers. Each accepted peer get's it own socket after accepting.
public final class Server: Stream {
    public let socket: Socket

    /// The dispatch queue that peers are accepted on.
    let queue: DispatchQueue
    let workers: [DispatchQueue]
    var worker: LoopIterator<[DispatchQueue]>

    /// Creates a new Server Socket
    ///
    /// - parameter hostname: The hostname to listen to. By default, all hostnames will be accepted
    /// - parameter port: The port to listen on.
    /// - throws: If reserving a socket failed.
    public convenience init(hostname: String = "0.0.0.0", port: UInt16) throws {
        let socket = try Socket(hostname: hostname, port: port, isServer: true)
        self.init(socket: socket)
    }

    public init(socket: Socket) {
        self.socket = socket
        self.queue = DispatchQueue(label: "codes.vapor.net.tcp.server.main", qos: .userInteractive)
        var workers: [DispatchQueue] = []
        for i in 1...4 {
            let worker = DispatchQueue(label: "codes.vapor.net.tcp.server.worker.\(i)", qos: .userInteractive)
            workers.append(worker)
        }
        worker = LoopIterator(collection: workers)
        self.workers = workers
    }

    // Stores all clients so they won't be deallocated in the async process
    // Refers to clients by their file descriptor
    var clients = [Int32: Client]()

    var connectSource: DispatchSourceRead?

    /// Starts listening for peers asynchronously
    ///
    /// - parameter maxIncomingConnections: The maximum backlog of incoming connections. Defaults to 4096.
    public func start(maxIncomingConnections: Int32 = 4096) throws {
        // Cast the address
        let addr =  UnsafeMutablePointer<sockaddr>(OpaquePointer(socket.address))
        let addrSize = socklen_t(MemoryLayout<sockaddr_in>.size)

        // Bind to the address
        guard bind(socket.descriptor, addr, addrSize) > -1 else {
            throw "TCPError.bindFailure"
        }

        // Start listening on the address
        guard listen(socket.descriptor, maxIncomingConnections) > -1 else {
            throw "TCPError.bindFailure"
        }

        let connectSource = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor,
            queue: queue
        )
        self.connectSource = connectSource

        let bufferQueue = DispatchQueue(label: "codes.vapor.net.tcp.server.buffer")

        // For every connected client, this closure triggers
        connectSource.setEventHandler {
            // Prepare for a client's connection
            let addr = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
            let addrSockAddr = UnsafeMutablePointer<sockaddr>(OpaquePointer(addr))
            var a = socklen_t(MemoryLayout<sockaddr_storage>.size)

            // Accept the new client
            let clientDescriptor = accept(self.socket.descriptor, addrSockAddr, &a)

            // If the accept failed, deallocate the reserved address memory and return
            guard clientDescriptor > -1 else {
                addr.deallocate(capacity: 1)
                return
            }

            let clientSocket = Socket(descriptor: clientDescriptor, isServer: false)

            let queue = self.worker.next() ?? self.queue
            let client = Client(socket: clientSocket, queue: queue)

//            let client = RemoteClient(descriptor: clientDescriptor, addr: addr) {
//                self.bufferQueue.sync {
//                    self.clients[clientDescriptor] = nil
//                    // FIXME:
//                    // addr.deallocate(capacity: 1)
//                }
//            }

            bufferQueue.sync {
                self.clients[clientDescriptor] = client
            }

            self.closures.forEach { try! $0(client) }
        }

        connectSource.resume()
    }

    // MARK: Stream

    public typealias Output = Client
    public typealias ClientHandler = (Client) throws -> (Void)
    var closures: [ClientHandler] = []
    
    public func then(_ closure: @escaping ClientHandler) {
        closures.append(closure)
    }
}



// MARK: Utilties

public struct LoopIterator<Base: Collection>: IteratorProtocol {
    private let collection: Base
    private var index: Base.Index

    public init(collection: Base) {
        self.collection = collection
        self.index = collection.startIndex
    }

    public mutating func next() -> Base.Iterator.Element? {
        guard !collection.isEmpty else {
            return nil
        }

        let result = collection[index]
        collection.formIndex(after: &index) // (*) See discussion below
        if index == collection.endIndex {
            index = collection.startIndex
        }
        return result
    }
}

