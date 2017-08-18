import Streams
import Dispatch

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/// Used as a simple global variable, to prevent too many allocations
/// A socket's length is always 4 since it's a UInt32
fileprivate var len: socklen_t = socklen_t(MemoryLayout<UInt32>.size)

/// Any TCP socket. It doesn't specify being a server or client yet.
public class TCPSocket {
    /// Sockets stream buffers of bytes
    public typealias Streamable = UnsafeBufferPointer<UInt8>
    
    /// A ReadSource that will trigger the internal on-read function when the socket contains more data
    let readSource: DispatchSourceRead
    
    /// A DispatchQueue that handles all TCP connections if no other is provided
    static let queue = DispatchQueue(label: "org.openkitten.lynx.socket")
    
    /// The socket's address storage
    ///
    /// For servers, the hostname at which connections are accepted
    ///
    /// For clients, the hostname that is being connected to
    var socketAddress = UnsafeMutablePointer<sockaddr_storage>.allocate(capacity: 1)
    
    public init(hostname: String, port: UInt16, client: Bool, dispatchQueue queue: DispatchQueue? = nil) throws {
        var addressCriteria = addrinfo.init()
        
        // Support both IPv4 and IPv6
        addressCriteria.ai_family = Int32(AF_INET)
        
        if !client {
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
            throw TCPError.bindFailure
        }
        
        guard let info = addrInfo else { throw TCPError.bindFailure }
        
        defer { freeaddrinfo(info) }
        
        guard let addr = info.pointee.ai_addr else { throw TCPError.bindFailure }
        
        socketAddress.initialize(to: sockaddr_storage())
        
        let _addr = UnsafeMutablePointer<sockaddr_in>.init(OpaquePointer(addr))!
        let specPtr = UnsafeMutablePointer<sockaddr_in>(OpaquePointer(socketAddress))
        specPtr.assign(from: _addr, count: 1)
        
        // Open the socket, get the descriptor
        self.descriptor = socket(addressCriteria.ai_family, addressCriteria.ai_socktype, addressCriteria.ai_protocol)
        
        guard descriptor > -1 else {
            throw TCPError.bindFailure
        }
        
        // Set the socket to async/non blocking I/O
        guard fcntl(self.descriptor, F_SETFL, O_NONBLOCK) > -1 else {
            throw TCPError.bindFailure
        }
        
        var yes = 1
        
        guard setsockopt(self.descriptor, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int>.size)) > -1 else {
            throw TCPError.bindFailure
        }
        
        // Set up the read source so that reading happens asynchronously using DispatchSources
        self.readSource = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue ?? TCPSocket.queue)
        
        self.readSource.setCancelHandler(handler: self.cleanup)
    }
    
    /// Called when closing the socket
    ///
    /// In charge of cleaning everything, from the socket's file descriptor to the SSL layer and anything extra
    ///
    /// Do **not** call this manually, or your application will very likely crash.
    open func cleanup() {
        #if os(Linux)
            Glibc.close(self.descriptor)
        #else
            Darwin.close(self.descriptor)
        #endif
    }
    
    /// Closes the socket.
    open func close() {
        self.readSource.cancel()
    }
    
    /// The file descriptor related to this socket
    public let descriptor: Int32
    
    /// Returns a boolean describing if the socket is still healthy and open
    public var isConnected: Bool {
        var error = 0
        getsockopt(self.descriptor, SOL_SOCKET, SO_ERROR, &error, &len)
        
        return error == 0
    }
}
