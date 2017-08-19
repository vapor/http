import Core
import Dispatch
import libc

/// Used as a simple global variable, to prevent too many allocations
/// A socket's length is always 4 since it's a UInt32
fileprivate var len: socklen_t = socklen_t(MemoryLayout<UInt32>.size)

/// Any TCP socket. It doesn't specify being a server or client yet.
public class Socket {
    /// The file descriptor related to this socket
    public let descriptor: Int32
    
    /// The socket's address storage
    ///
    /// For servers, the hostname at which connections are accepted
    ///
    /// For clients, the hostname that is being connected to
    var address = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
    
    /// `true` when this socket is a server socket
    let isServer: Bool
    
    internal init(descriptor: Int32, isServer: Bool) {
        self.descriptor = descriptor
        self.isServer = isServer
    }
    
    /// Creates a new TCP socket
    ///
    /// - parameter hostname: For servers, the hostname on which clients are accepted. For clients, the hostname to connect to
    /// - parameter port: For servers, the port to accept on. For clients, the port to connect to
    /// - parameter client: `true` if the connection is for a server, `false` for clients
    /// - parameter queue: The dispatch queue on which read callbacks are dispatched.b
    internal init(hostname: String, port: UInt16, isServer: Bool) throws {
        self.isServer = isServer
        
        var addressCriteria = addrinfo.init()
        
        // Support both IPv4 and IPv6
        addressCriteria.ai_family = Int32(AF_INET)
        
        if isServer {
            addressCriteria.ai_flags = AI_PASSIVE
        }
        
        // Specify that this is a TCP Stream
        #if os(Linux)
            addressCriteria.ai_socktype = Int32(SOCK_STREAM.rawValue)
            addressCriteria.ai_protocol = Int32(IPPROTO_TCP)
        #else
            addressCriteria.ai_socktype = SOCK_STREAM
            addressCriteria.ai_protocol = IPPROTO_TCP
        #endif
        
        // Look ip the sockeaddr for the hostname
        var addrInfo: UnsafeMutablePointer<addrinfo>?
        
        guard getaddrinfo(hostname, port.description, &addressCriteria, &addrInfo) > -1 else {
            throw "TCPError.bindFailure"
        }
        
        guard let info = addrInfo else {
            throw "TCPError.bindFailure"
        }
        
        defer { freeaddrinfo(info) }
        
        guard let addr = info.pointee.ai_addr else {
            throw "TCPError.bindFailure"
        }
        
        address.initialize(to: sockaddr_storage())
        
        let _addr = UnsafeMutablePointer<sockaddr_in>.init(OpaquePointer(addr))!
        let specPtr = UnsafeMutablePointer<sockaddr_in>(OpaquePointer(address))
        specPtr.assign(from: _addr, count: 1)
        
        // Open the socket, get the descriptor
        self.descriptor = socket(addressCriteria.ai_family, addressCriteria.ai_socktype, addressCriteria.ai_protocol)
        
        guard descriptor > -1 else {
            throw "TCPError.bindFailure"
        }
        
        // Set the socket to async/non blocking I/O
        guard fcntl(self.descriptor, F_SETFL, O_NONBLOCK) > -1 else {
            throw "TCPError.bindFailure"
        }
        
        var yes = 1
        
        guard setsockopt(self.descriptor, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int>.size)) > -1 else {
            throw "TCPError.bindFailure"
        }
    }

    /// Closes the socket
    public func close() {
        #if os(Linux)
            Glibc.close(self.descriptor)
        #else
            Darwin.close(self.descriptor)
        #endif
    }
    
    /// Returns a boolean describing if the socket is still healthy and open
    public var isConnected: Bool {
        var error = 0
        getsockopt(self.descriptor, SOL_SOCKET, SO_ERROR, &error, &len)
        
        return error == 0
    }

    deinit {
        close()
        address.deallocate(capacity: 1)
    }
}
