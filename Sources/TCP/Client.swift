import Core
import Dispatch
import Foundation
import libc

/// The remote peer of a `ServerSocket`
public final class Client: Core.Stream {
    public let socket: Socket

    /// A closure that can be called whenever the socket encountered a critical error
    public var onError: ((Error) -> ())? = nil

    /// The maximum amount of data inside `pointer`
    let pointerSize: Int

    /// The amount of data currently in `pointer`
    var read = 0

    /// A pointer containing a maximum of `self.pointerSize` of data
    let pointer: UnsafeMutablePointer<UInt8>

    let queue: DispatchQueue
    let channel: DispatchIO

    /// Creates a new Remote Client from the ServerSocket's details
    init(socket: Socket, queue: DispatchQueue) {
        self.socket = socket
        self.queue = queue

        // Allocate one TCP packet
        self.pointerSize = 65_507
        self.pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.pointerSize)
        self.pointer.initialize(to: 0, count: self.pointerSize)
        self.channel = DispatchIO(
            type: .stream,
            fileDescriptor: socket.descriptor,
            queue: queue,
            cleanupHandler: {
                int in
            }
        )
    }

    var readSource: DispatchSourceRead?
    var writeSource: DispatchSourceWrite?

    public func close() {
        readSource?.cancel()
        socket.close()
    }

    var queuedData: DispatchData?

    public func write(_ data: DispatchData) {
        if queuedData == nil {
            queuedData = data
        } else {
            queuedData?.append(data)
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
//        channel.write(
//            offset: 0,
//            data: data,
//            queue: queue
//        ) { done, data, err in
//            if err != 0 {
//                print("there was a write err")
//            }
//
//            if done {
//                return
//            }
//
//            if let data = data {
//                self.write(data)
//            }
//        }
    }

    /// Starts receiving data from the client
    public func listen() {
        let readSource = DispatchSource.makeReadSource(
            fileDescriptor: socket.descriptor,
            queue: queue
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

            let buffer = ByteBuffer(
                start: self.pointer,
                count: self.read
            )
            self.closures.forEach { try! $0(buffer) }
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
    public typealias ByteBufferHandler = (ByteBuffer) throws -> (Void)
    var closures: [ByteBufferHandler] = []

    /// Registers a closure that must be executed for every `Output` event
    ///
    /// - parameter closure: The closure to execute for each `Output` event
    public func then(_ closure: @escaping ByteBufferHandler) {
        closures.append(closure)
    }
}

