import Core
import Dispatch
import libc

/// A server socket can accept peers. Each accepted peer get's it own socket after accepting.
public final class Server: Core.OutputStream {
    // MARK: Stream
    public typealias Output = Client
    public var error: ErrorHandler?
    public var output: OutputHandler?

    // MARK: Dispatch

    /// The dispatch queue that peers are accepted on.
    public let queue: DispatchQueue

    // MARK: Internal

    let socket: Socket
    let workers: [DispatchQueue]
    var worker: LoopIterator<[DispatchQueue]>
    var readSource: DispatchSourceRead?
    var clients = [Descriptor: Client]()

    /// Creates a new Server Socket
    ///
    /// - parameter hostname: The hostname to listen to. By default, all hostnames will be accepted
    /// - parameter port: The port to listen on.
    /// - throws: If reserving a socket failed.
    public convenience init() throws {
        let socket = try Socket()
        self.init(socket: socket)
    }

    public init(socket: Socket) {
        self.socket = socket
        self.queue = DispatchQueue(label: "codes.vapor.net.tcp.server.main", qos: .userInteractive)
        var workers: [DispatchQueue] = []
        for i in 1...8 {
            let worker = DispatchQueue(label: "codes.vapor.net.tcp.server.worker.\(i)", qos: .userInteractive)
            workers.append(worker)
        }
        worker = LoopIterator(collection: workers)
        self.workers = workers
    }

    /// Starts listening for peers asynchronously
    ///
    /// - parameter maxIncomingConnections: The maximum backlog of incoming connections. Defaults to 4096.
    public func start(hostname: String = "0.0.0.0", port: UInt16, backlog: Int32 = 4096) throws {
        try socket.bind(hostname: hostname, port: port)
        try socket.listen()

        let buffer = DispatchQueue(label: "codes.vapor.net.tcp.server.buffer")
        readSource = socket.onReadable(queue: queue) {
            let socket: Socket
            do {
                socket = try self.socket.accept()
            } catch {
                self.error?(error)
                return
            }

            let queue = self.worker.next()!
            let client = Client(socket: socket, queue: queue)
            client.error = self.error
            self.output?(client)

            buffer.sync {
                self.clients[client.socket.descriptor] = client
            }

            client.onClose = {
                buffer.sync {
                    self.clients[client.socket.descriptor] = nil
                }
            }

        }
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

