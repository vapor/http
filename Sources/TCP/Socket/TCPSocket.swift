import Async
import Bits
import COperatingSystem
import Foundation

/// Any TCP socket. It doesn't specify being a server or client yet.
public struct TCPSocket: Socket {
    /// A reference wrapper to allow mutating the descriptor's value in an
    /// otherwise immutable struct. (Think C++'s `mutable`. Sigh.)
    private final class MutableDescriptor {
        var value: Int32 = -1
    }

    /// Underlying mutable storage for the descriptor
    private let _descriptor = MutableDescriptor()
    
    /// The file descriptor related to this socket
    public var descriptor: Int32 { return _descriptor.value }

    /// The remote's address
    public var address: TCPAddress?

    /// True if the socket is non blocking
    public let isNonBlocking: Bool

    /// True if the socket should re-use addresses
    public let shouldReuseAddress: Bool

    /// Creates a TCP socket around an existing descriptor
    public init(
        established: Int32,
        isNonBlocking: Bool,
        shouldReuseAddress: Bool,
        address: TCPAddress?
    ) {
        self._descriptor.value = established
        self.isNonBlocking = isNonBlocking
        self.shouldReuseAddress = shouldReuseAddress
        self.address = address
    }

    /// Creates a new TCP socket
    public init(
        isNonBlocking: Bool = true,
        shouldReuseAddress: Bool = true
    ) throws {
        let sockfd = socket(AF_INET, SOCK_STREAM, 0)
        guard sockfd > 0 else {
            throw TCPError.posix(errno, identifier: "socketCreate")
        }

        if isNonBlocking {
            // Set the socket to async/non blocking I/O
            guard fcntl(sockfd, F_SETFL, O_NONBLOCK) == 0 else {
                throw TCPError.posix(errno, identifier: "setNonBlocking")
            }
        }

        if shouldReuseAddress {
            var yes = 1
            let intSize = socklen_t(MemoryLayout<Int>.size)
            guard setsockopt(sockfd, SOL_SOCKET, SO_REUSEPORT, &yes, intSize) == 0 else {
                throw TCPError.posix(errno, identifier: "setReuseAddress")
            }
        }

        if shouldReuseAddress {
            var yes = 1
            let intSize = socklen_t(MemoryLayout<Int>.size)
            guard setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &yes, intSize) == 0 else {
                throw TCPError.posix(errno, identifier: "setReuseAddress")
            }
        }

        self.init(
            established: sockfd,
            isNonBlocking: isNonBlocking,
            shouldReuseAddress: shouldReuseAddress,
            address: nil
        )
    }

    /// Disables broken pipe from signaling this process.
    /// Broken pipe is common on the internet and if uncaught
    /// it will kill the process.
    public func disablePipeSignal() {
        signal(SIGPIPE, SIG_IGN)

        #if !os(Linux)
            var n = 1
            setsockopt(self.descriptor, SOL_SOCKET, SO_NOSIGPIPE, &n, numericCast(MemoryLayout<Int>.size))
        #endif

        // TODO: setsockopt(self.descriptor, SOL_TCP, TCP_NODELAY, &n, numericCast(MemoryLayout<Int>.size)) ?
    }

    /// Read data from the socket into the supplied buffer.
    /// Returns the amount of bytes actually read.
    public func read(into buffer: MutableByteBuffer) throws -> SocketReadStatus {
        let receivedBytes = COperatingSystem.read(descriptor, buffer.baseAddress!, buffer.count)

        guard receivedBytes != -1 else {
            switch errno {
            case EINTR:
                // try again
                return try read(into: buffer)
            case ECONNRESET:
                // closed by peer, need to close this side.
                // Since this is not an error, no need to throw unless the close
                // itself throws an error.
                _ = close()
                return .read(count: 0)
            case EAGAIN, EWOULDBLOCK:
                // no data yet
                return .wouldBlock
            default:
                throw TCPError.posix(errno, identifier: "read")
            }
        }

        guard receivedBytes > 0 else {
            // receiving 0 indicates a proper close .. no error.
            // attempt a close, no failure possible because throw indicates already closed
            // if already closed, no issue.
            // do NOT propogate as error
            self.close()
            return .read(count: 0)
        }

        return .read(count: receivedBytes)
    }

    /// Writes all data from the pointer's position with the length specified to this socket.
    public func write(from buffer: ByteBuffer) throws -> SocketWriteStatus {
        guard let pointer = buffer.baseAddress else {
            return .wrote(count: 0)
        }

        let sent = send(descriptor, pointer, buffer.count, 0)

        guard sent != -1 else {
            switch errno {
            case EINTR:
                // try again
                return try write(from: buffer)
            case ECONNRESET:
                // closed by peer, need to close this side.
                // Since this is not an error, no need to throw unless the close
                // itself throws an error.
                self.close()
                return .wrote(count: 0)
            case EBADF:
                // closed by peer and already invalid, update the descriptor so
                // we don't keep trying to reuse a stale value
                _descriptor.value = -1
                // - TODO: This should really throw, are there any actual cases where EBADF replaces ECONNRESET?
                return .wrote(count: 0)
            case EAGAIN, EWOULDBLOCK:
                return .wouldBlock
            default:
                throw TCPError.posix(errno, identifier: "write")
            }
        }

        return .wrote(count: sent)
    }
    
    /// Closes the socket
    public func close() {
        // Don't waste a syscall on a known-invalid descriptor
        if descriptor != -1 {
            let _ = COperatingSystem.close(descriptor)
            _descriptor.value = -1
        }
    }
}
