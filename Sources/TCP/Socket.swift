import Core
import Dispatch
import libc

/// Any TCP socket. It doesn't specify being a server or client yet.
public class Socket {
    /// The file descriptor related to this socket
    public let descriptor: Descriptor

    /// True if the socket is non blocking
    public let isNonBlocking: Bool

    /// True if the socket should re-use addresses
    public let shouldReuseAddress: Bool

    /// Creates a TCP socket around an existing descriptor
    public init(
        established: Descriptor,
        isNonBlocking: Bool,
        shouldReuseAddress: Bool
    ) {
        self.descriptor = established
        self.isNonBlocking = isNonBlocking
        self.shouldReuseAddress = shouldReuseAddress
    }
    
    /// Creates a new TCP socket
    public convenience init(
        isNonBlocking: Bool = true,
        shouldReuseAddress: Bool = true
    ) throws {
        let sockfd = socket(AF_INET, SOCK_STREAM, 0)
        guard sockfd > 0 else {
            throw "Failed to create socket"
        }
        let descriptor = Descriptor(raw: sockfd)

        if isNonBlocking {
            // Set the socket to async/non blocking I/O
            guard fcntl(descriptor.raw, F_SETFL, O_NONBLOCK) == 0 else {
                throw "setting nonblock failed"
            }
        }

        if shouldReuseAddress {
            var yes = 1
            guard setsockopt(descriptor.raw, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int>.size)) == 0 else {
                throw "setting reuse addr failed"
            }
        }

        self.init(
            established: descriptor,
            isNonBlocking: isNonBlocking,
            shouldReuseAddress: shouldReuseAddress
        )
    }

    public func connect(hostname: String = "localhost", port: UInt16 = 80) throws {
        var hints = addrinfo()

        // Support both IPv4 and IPv6
        hints.ai_family = AF_INET

        // Specify that this is a TCP Stream
        hints.ai_socktype = SOCK_STREAM

        // Look ip the sockeaddr for the hostname
        var result: UnsafeMutablePointer<addrinfo>?

        var res = getaddrinfo(hostname, port.description, &hints, &result)
        guard res == 0 else {
            perror("connect")
            throw "get addr info failed"
        }
        defer {
            freeaddrinfo(result)
        }

        guard let info = result else {
            throw "nil result"
        }

        res = libc.connect(descriptor.raw, info.pointee.ai_addr, info.pointee.ai_addrlen)
        guard res == 0 || (isNonBlocking && errno == EINPROGRESS) else {
            perror("connect")
            throw "connect error: \(errno)"
        }
    }


    public func bind(hostname: String = "localhost", port: UInt16 = 80) throws {
        var hints = addrinfo()

        // Support both IPv4 and IPv6
        hints.ai_family = AF_INET

        // Specify that this is a TCP Stream
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP

        // If the AI_PASSIVE flag is specified in hints.ai_flags, and node is
        // NULL, then the returned socket addresses will be suitable for
        // bind(2)ing a socket that will accept(2) connections.
        hints.ai_flags = AI_PASSIVE


        // Look ip the sockeaddr for the hostname
        var result: UnsafeMutablePointer<addrinfo>?

        var res = getaddrinfo(hostname, port.description, &hints, &result)
        guard res == 0 else {
            perror("connect")
            throw "get addr info failed"
        }
        defer {
            freeaddrinfo(result)
        }

        guard let info = result else {
            throw "nil result"
        }

        res = libc.bind(descriptor.raw, info.pointee.ai_addr, info.pointee.ai_addrlen)
        guard res == 0 else {
            perror("bind")
            throw "connect error: \(errno)"
        }
    }

    public func listen(backlog: Int32 = 4096) throws {
        let res = libc.listen(descriptor.raw, backlog)
        guard res == 0 else {
            perror("listen")
            throw "connect error: \(errno)"
        }
    }


    public func accept() throws -> Socket {
        let clientfd = libc.accept(descriptor.raw, nil, nil)
        guard clientfd > 0 else {
            throw "invalid client fd"
        }

        return Socket(
            established: Descriptor(raw: clientfd),
            isNonBlocking: isNonBlocking,
            shouldReuseAddress: shouldReuseAddress
        )
    }

    /// Closes the socket
    public func close() {
        libc.close(descriptor.raw)
    }
    
    /// Returns a boolean describing if the socket is still healthy and open
    public var isConnected: Bool {
        var error = 0
        getsockopt(descriptor.raw, SOL_SOCKET, SO_ERROR, &error, nil)
        
        return error == 0
    }

    deinit {
        close()
    }
}
