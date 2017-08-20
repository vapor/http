import Core
import Dispatch
import Foundation
import libc

/// The remote peer of a `ServerSocket`
public final class Client: Core.Stream {
    // MARK: Stream
    public typealias Input = DispatchData
    public typealias Output = ByteBuffer
    public var error: ErrorHandler?
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
    var onClose: SocketEvent?

    /// Creates a new Remote Client from the ServerSocket's details
    public init(socket: Socket, queue: DispatchQueue) {
        self.socket = socket
        self.queue = queue

        // Allocate one TCP packet
        let size = 65_507
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: size)
        self.buffer = MutableByteBuffer(start: pointer, count: size)
    }

    // MARK: Public methods

    public func input(_ input: DispatchData) {
        write(input)
    }

    public func input(_ data: Data) {
        let pointer = BytesPointer(data.withUnsafeBytes { $0 })
        let buffer = UnsafeRawBufferPointer(start: pointer, count: data.count)
        let dispatch = DispatchData(bytes: buffer)
        write(dispatch)
    }

    public func write(_ input: DispatchData) {
        if queuedData == nil {
            queuedData = input
        } else {
            queuedData?.append(input)
        }

        if writeSource == nil {
            writeSource = socket.onWriteable(queue: queue) {
                self.writeSource?.suspend()
                guard let data = self.queuedData else {
                    return
                }
                self.queuedData = nil

                let copied = Data(data)
                let buffer = ByteBuffer(start: copied.withUnsafeBytes { $0 }, count: copied.count)
                do {
                    try self.socket.write(max: copied.count, from: buffer)
                } catch {
                    self.error?(error)
                }
            }
        } else {
            writeSource?.resume()
        }

    }

    /// Starts receiving data from the client
    public func listen() {
        readSource = socket.onReadable(queue: queue) {
            // print(String(cString: __dispatch_queue_get_label(nil), encoding: .utf8) == self.queue.label)
            let read: Int

            do {
                read = try self.socket.read(max: self.buffer.count, into: self.buffer)
            } catch {
                self.error?(error)
                return
            }

            let frame = ByteBuffer(
                start: self.buffer.baseAddress,
                count: read
            )

            self.output?(frame)
        }
    }

    public func close() {
        readSource?.cancel()
        writeSource?.cancel()
        socket.close()
        onClose?()
    }

    // MARK: Utilities

    /// Deallocated the pointer buffer
    deinit {
        print("deinit")
        close()
        guard let pointer = buffer.baseAddress else {
            return
        }
        pointer.deinitialize(count: buffer.count)
        pointer.deallocate(capacity: buffer.count)
    }
}

