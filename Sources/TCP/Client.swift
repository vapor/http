import Core
import Dispatch
import Foundation
import libc

/// The remote peer of a `ServerSocket`
public final class Client: Core.Stream {
    let socket: Socket

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
            guard let (data, callback) = self.input else {
                return
            }
            
            defer { self.input = nil }
            
            do {
                let buffer = ByteBuffer.init(start: data.withUnsafeBytes { $0 }, count: data.count)
                try self.socket.write(max: data.count, from: buffer)
            } catch {
                _ = try? callback.complete(error)
            }
        }
        
        writeSource.resume()
    }

    let readQueue: DispatchQueue
    var readSource: DispatchSourceRead?

    let writeQueue: DispatchQueue
    let writeSource: DispatchSourceWrite
    var input: (DispatchData, ManualFuture<Void>)?

    public func write(_ data: DispatchData) throws {
        let future = ManualFuture<Void>()
        
        self.input = (data, future)
        
        try future.await()
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
            
            _ = try? self.stream.write(buffer)
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

    /// The underlying stream helper
    let stream = BasicStream<Output>()

    /// Registers a closure that must be executed for every `Output` event
    ///
    /// - parameter closure: The closure to execute for each `Output` event
    public func then(_ closure: @escaping ((ByteBuffer) throws -> (Future<Void>))) {
        stream.then(closure)
    }
}

