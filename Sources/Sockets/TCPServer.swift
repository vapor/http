import Core
import Dispatch
import libc

/// A server socket can accept peers. Each accepted peer get's it own socket after accepting.
public final class TCPServer: Stream {
    public let socket: TCPSocket

    /// The dispatch queue that peers are accepted on.
    let queue: DispatchQueue
    let bufferQueue = DispatchQueue(label: "codes.vapor.clientBufferQueue", qos: .userInteractive)
    let cleanupQueue = DispatchQueue(label: "codes.vapor.clientBufferQueue", qos: .background)

    /// Creates a new Server Socket
    ///
    /// - parameter hostname: The hostname to listen to. By default, all hostnames will be accepted
    /// - parameter port: The port to listen on.
    /// - throws: If reserving a socket failed.
    public init(hostname: String = "0.0.0.0", port: UInt16) throws {
        // Default to `.userInteractive` because this is a single thread responsible for *all* incoming connections
        self.queue = DispatchQueue(label: "codes.vapor.clientConnectQueue", qos: .userInteractive)
        self.socket = try TCPSocket(hostname: hostname, port: port, isServer: true)
    }

    public init(socket: TCPSocket) {
        self.socket = socket
        self.queue = DispatchQueue(label: "codes.vapor.clientConnectQueue", qos: .userInteractive)
    }

    // Stores all clients so they won't be deallocated in the async process
    // Refers to clients by their file descriptor
    var clients = [Int32: TCPClient]()

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
            throw TCPError.bindFailure
        }

        // Start listening on the address
        guard listen(socket.descriptor, maxIncomingConnections) > -1 else {
            throw TCPError.bindFailure
        }

        let connectSource = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor,
            queue: queue
        )
        self.connectSource = connectSource

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

            let clientSocket = TCPSocket(descriptor: clientDescriptor, isServer: false)
            let client = TCPClient(socket: clientSocket)

//            let client = RemoteClient(descriptor: clientDescriptor, addr: addr) {
//                self.bufferQueue.sync {
//                    self.clients[clientDescriptor] = nil
//                    // FIXME:
//                    // addr.deallocate(capacity: 1)
//                }
//            }

            self.bufferQueue.sync {
                self.clients[clientDescriptor] = client
            }

            self.branchStreams.forEach { branch in
                try! branch(client)
            }
        }

        connectSource.resume()
    }

    // MARK: Stream

    public typealias Output = TCPClient

    /// Internal typealias used to define a cascading callback
    typealias ProcessOutputCallback = ((Output) throws -> ())

    /// All entities waiting for a new packet
    var branchStreams = [ProcessOutputCallback]()

    /// Maps this stream of data to a stream of other information
    public func map<T>(_ closure: @escaping ((Output) throws -> (T?))) -> StreamTransformer<Output, T> {
        let stream = StreamTransformer<Output, T>(using: closure)
        branchStreams.append(stream.process)
        return stream
    }
}

