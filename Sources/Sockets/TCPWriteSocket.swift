import Dispatch

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

extension TCPSocket {
    /// Writes all data from the pointer's position with the length specified to this socket.
    ///
    /// - parameter pointer: The pointer to the start of the buffer
    /// - parameter length: The length of the buffer to send
    /// - throws: If the socket is disconnected
    /// - returns: The amount of bytes written
    @discardableResult
    public func write(contentsAt pointer: UnsafePointer<UInt8>, withLengthOf length: Int) throws -> Int {
        #if os(Linux)
            let sent = Glibc.send(self.descriptor, pointer, length, 0)
        #else
            let sent = Darwin.send(self.descriptor, pointer, length, 0)
        #endif
        
        guard sent != -1 else {
            switch errno {
            case EINTR:
                // try again
                return try self.write(contentsAt: pointer, withLengthOf: length)
            case ECONNRESET:
                // closed by peer, need to close this side.
                // Since this is not an error, no need to throw unless the close
                // itself throws an error.
                self.close()
                return 0
            default:
                throw TCPError.sendFailure
            }
        }
        
        return sent
    }
}
