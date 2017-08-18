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
    
    public init(hostname: String, port: UInt16, dispatchQueue queue: DispatchQueue? = nil) throws {
        var addressCriteria = addrinfo.init()
        // IPv4 or IPv6
        addressCriteria.ai_family = Int32(AF_INET)
        addressCriteria.ai_flags = AI_PASSIVE
        
        #if os(Linux)
            addressCriteria.ai_socktype = Int32(SOCK_STREAM.rawValue)
            addressCriteria.ai_protocol = Int32(IPPROTO_TCP)
        #else
            addressCriteria.ai_socktype = SOCK_STREAM
            addressCriteria.ai_protocol = IPPROTO_TCP
        #endif
        
        var addrInfo: UnsafeMutablePointer<addrinfo>?
        
        guard getaddrinfo(hostname, port.description, &addressCriteria, &addrInfo) > -1 else {
            throw TCPError.bindFailed
        }
        
        guard let info = addrInfo else { throw TCPError.bindFailed }
        
        defer { freeaddrinfo(info) }
        
        guard let addr = info.pointee.ai_addr else { throw TCPError.bindFailed }
        
        socketAddress.initialize(to: sockaddr_storage())
        
        let _addr = UnsafeMutablePointer<sockaddr_in>.init(OpaquePointer(addr))!
        let specPtr = UnsafeMutablePointer<sockaddr_in>(OpaquePointer(socketAddress))
        specPtr.assign(from: _addr, count: 1)
        
        self.descriptor = socket(addressCriteria.ai_family, addressCriteria.ai_socktype, addressCriteria.ai_protocol)
        
        guard descriptor > -1 else {
            throw TCPError.bindFailed
        }
        
        guard fcntl(self.descriptor, F_SETFL, O_NONBLOCK) > -1 else {
            throw TCPError.bindFailed
        }
        
        var yes = 1
        
        guard setsockopt(self.descriptor, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int>.size)) > -1 else {
            throw TCPError.bindFailed
        }
        
        self.readSource = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue ?? TCPSocket.queue)
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
