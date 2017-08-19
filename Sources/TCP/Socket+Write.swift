import Core
import Dispatch
import libc

extension Socket {
    /// Writes all data from the pointer's position with the length specified to this socket.
    ///
    /// - parameter pointer: The pointer to the start of the buffer
    /// - parameter length: The length of the buffer to send
    /// - throws: If the socket is disconnected
    /// - returns: The amount of bytes written
    @discardableResult
    public func write(max: Int, from buffer: ByteBuffer) throws -> Int {
        guard let pointer = buffer.baseAddress else {
            return 0
        }

        let sent = send(self.descriptor, pointer, max, 0)
        guard sent != -1 else {
            switch errno {
            case EINTR:
                // try again
                return try write(max: max, from: buffer)
            case ECONNRESET:
                // closed by peer, need to close this side.
                // Since this is not an error, no need to throw unless the close
                // itself throws an error.
                self.close()
                return 0
            default:
                throw "TCPError.sendFailure"
            }
        }
        
        return sent
    }
}
