import Core
import Dispatch
import Foundation
import libc

/// The remote peer of a `ServerSocket`
public final class Client: Core.Stream {
    let socket: Socket

    public typealias OnRead = (ByteBuffer) -> ()
    public var onRead: OnRead?

    /// A closure that can be called whenever the socket encountered a critical error
    public var onError: ((Error) -> ())? = nil

    /// The maximum amount of data inside `pointer`
    let pointerSize: Int

    /// The amount of data currently in `pointer`
    var read = 0

    /// A pointer containing a maximum of `self.pointerSize` of data
    let pointer: UnsafeMutablePointer<UInt8>

    /// Creates a new Remote Client from the ServerSocket's details
    init(socket: Socket) {
        self.socket = socket
        self.readQueue = DispatchQueue(label: "codes.vapor.net.tcp.client.read", qos: .userInteractive)

        // Allocate one TCP packet
        self.pointerSize = 65_507
        self.pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.pointerSize)
        self.pointer.initialize(to: 0, count: self.pointerSize)

        let writeQueue = DispatchQueue(label: "codes.vapor.net.tcp.client.write", qos: .userInteractive)
        let writeSource = DispatchSource.makeWriteSource(fileDescriptor: socket.descriptor, queue: writeQueue)
        self.writeQueue = writeQueue
        self.writeSource = writeSource

        writeSource.setEventHandler {
            guard let data = self.writeData else {
                return
            }
            self.writeData = nil
            let copied = Data(data)
            let buffer = ByteBuffer.init(start: copied.withUnsafeBytes { $0 }, count: copied.count)
            try! self.socket.write(max: copied.count, from: buffer)
        }
        writeSource.resume()
    }

    let readQueue: DispatchQueue
    var readSource: DispatchSourceRead?

    let writeQueue: DispatchQueue
    let writeSource: DispatchSourceWrite
    var writeData: DispatchData?

    public func write(_ data: DispatchData) {
        if writeData == nil {
            writeData = data
        } else {
            writeData?.append(data)
        }
    }

    public func close() {
        readSource?.cancel()
        writeSource.cancel()
        socket.close()
    }

    /// Starts receiving data from the client
    public func listen() {
        let readSource = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor,
            queue: readQueue
        )
        self.readSource = readSource

        readSource.setEventHandler {
            self.read = recv(self.socket.descriptor, self.pointer, self.pointerSize, 0)

            guard self.read > -1 else {
                self.handleError("TCPError.readFailure")
                return
            }

            guard self.read != 0 else {
                self.socket.close()
                return
            }

            let buffer = UnsafeBufferPointer(
                start: self.pointer,
                count: self.read
            )

            self.onRead?(buffer)
            self.branchStreams.forEach { stream in
                _ = try? stream(buffer)
            }
        }

        readSource.resume()
    }

    /// Takes care of error handling
    func handleError(_ error: Error) {
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

