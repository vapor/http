import Core
import Dispatch
import libc

public typealias MutableByteBuffer = UnsafeMutableBufferPointer<Byte>
extension String: Error { }

extension TCPSocket {
    public func read(max: Int, into buffer: MutableByteBuffer) throws -> Int {
        let receivedBytes = libc.read(descriptor, buffer.baseAddress.unsafelyUnwrapped, max)

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
