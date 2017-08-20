import Core
import Dispatch
import Foundation
import libc

extension Socket {
    public func read(max: Int) throws -> Data {
        var pointer = MutableBytesPointer.allocate(capacity: max)
        defer {
            pointer.deallocate(capacity: max)
            pointer.deinitialize(count: max)
        }
        let buffer = MutableByteBuffer(start: pointer, count: max)
        let read = try self.read(max: max, into: buffer)
        let frame = ByteBuffer(start: pointer, count: read)
        return Data(buffer: frame)
    }

    public func onReadable(queue: DispatchQueue, event: @escaping SocketEvent) -> DispatchSourceRead {
        let source = DispatchSource.makeReadSource(
            fileDescriptor: descriptor.raw,
            queue: queue
        )
        source.setEventHandler {
            event()
        }
        source.resume()
        return source
    }

    public func read(max: Int, into buffer: MutableByteBuffer) throws -> Int {
        let receivedBytes = libc.read(descriptor.raw, buffer.baseAddress.unsafelyUnwrapped, max)

        guard receivedBytes != -1 else {
            switch errno {
            case EINTR:
                // try again
                return try read(max: max, into: buffer)
            case ECONNRESET:
                // closed by peer, need to close this side.
                // Since this is not an error, no need to throw unless the close
                // itself throws an error.
                _ = close()
                return 0
            case EAGAIN:
                // timeout reached (linux)
                return 0
            default:
                throw "SocketsError(.readFailed)"
            }
        }

        guard receivedBytes > 0 else {
            // receiving 0 indicates a proper close .. no error.
            // attempt a close, no failure possible because throw indicates already closed
            // if already closed, no issue.
            // do NOT propogate as error
            _ = close()
            return 0
        }

        return receivedBytes
    }
}
