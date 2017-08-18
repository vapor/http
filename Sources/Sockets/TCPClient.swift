import Core
import Dispatch
import libc

/// The remote peer of a `ServerSocket`
public final class TCPClient: Stream {
    public let socket: TCPSocket
    let queue: DispatchQueue

    /// A closure that can be called whenever the socket encountered a critical error
    public var onError: ((Error) -> ())? = nil

    /// The maximum amount of data inside `pointer`
    let pointerSize: Int

    /// The amount of data currently in `pointer`
    var read = 0

    /// A pointer containing a maximum of `self.pointerSize` of data
    let pointer: UnsafeMutablePointer<UInt8>

    /// Creates a new Remote Client from the ServerSocket's details
    init(socket: TCPSocket) {
        self.socket = socket
        self.queue = DispatchQueue(label: "codes.vapor.listen", qos: .userInteractive)

        // Allocate one TCP packet
        self.pointerSize = 65_507
        self.pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.pointerSize)
        self.pointer.initialize(to: 0, count: self.pointerSize)
    }

    var listenSource: DispatchSourceRead?

    /// Starts receiving data from the client
    public func listen() {
        let listenSource = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor,
            queue: queue
        )
        self.listenSource = listenSource

        listenSource.setEventHandler {
            self.read = recv(self.socket.descriptor, self.pointer, self.pointerSize, 0)

            guard self.read > -1 else {
                self.handleError(TCPError.readFailure)
                return
            }

            guard self.read != 0 else {
                self.socket.close()
                return
            }

            let buffer = UnsafeBufferPointer(start: self.pointer, count: self.read)

            for stream in self.branchStreams {
                _ = try? stream(buffer)
            }
        }

        listenSource.resume()
    }

    /// Takes care of error handling
    func handleError(_ error: TCPError) {
        self.socket.close()
        self.onError?(error)
    }

    /// Deallocated the pointer buffer
    deinit {
        pointer.deinitialize(count: self.pointerSize)
        pointer.deallocate(capacity: self.pointerSize)
    }

    // MARK: Stream

    public typealias Output = ByteBuffer

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

