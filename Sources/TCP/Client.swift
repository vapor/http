import Core
import Dispatch
import Foundation
import libc

/// The remote peer of a `ServerSocket`
public final class Client: Core.Stream {
    // MARK: Stream
    public typealias Input = DispatchData
    public typealias Output = ByteBuffer

    /// Output stream
    public var output: OutputHandler?

    // MARK: Dispatch

    /// This client's dispatch queue.
    public let queue: DispatchQueue

    // MARK: Internal

    let socket: Socket
    let buffer: MutableByteBuffer
    var readSource: DispatchSourceRead?
    var writeSource: DispatchSourceWrite?
    var queuedData: DispatchData?

    /// Creates a new Remote Client from the ServerSocket's details
    init(socket: Socket, queue: DispatchQueue) {
        self.socket = socket
        self.queue = queue

        // Allocate one TCP packet
        let size = 65_507
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        self.buffer = MutableByteBuffer(start: pointer, count: size)
    }

    // MARK: Public methods
    public func input(_ input: DispatchData) throws {
        if queuedData == nil {
            queuedData = input
        } else {
            queuedData?.append(input)
        }

        if writeSource == nil {
            let write = DispatchSource.makeWriteSource(fileDescriptor: socket.descriptor)
            self.writeSource = write
            write.setEventHandler {
                write.suspend()
                guard let data = self.queuedData else {
                    return
                }
                self.queuedData = nil

                let copied = Data(data)
                let buffer = ByteBuffer(start: copied.withUnsafeBytes { $0 }, count: copied.count)
                try! self.socket.write(max: copied.count, from: buffer)
            }
        }
        
        writeSource?.resume()
    }

    /// Starts receiving data from the client
    public func listen() {
        let readSource = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor,
            queue: queue
        )
        self.readSource = readSource

        readSource.setEventHandler {
            let read = try! self.socket.read(max: self.buffer.count, into: self.buffer)

            let frame = ByteBuffer(
                start: self.buffer.baseAddress,
                count: read
            )
            try! self.output?(frame)
        }

        readSource.resume()
    }

    public func close() {
        readSource?.cancel()
        socket.close()
    }

    // MARK: Utilities

    /// Deallocated the pointer buffer
    deinit {
        guard let pointer = buffer.baseAddress else {
            return
        }
        pointer.deinitialize(count: buffer.count)
        pointer.deallocate(capacity: buffer.count)
    }
}

