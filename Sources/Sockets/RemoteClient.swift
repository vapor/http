import Dispatch

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

/// The remote peer of a `ServerSocket`
public final class RemoteClient : TCPSocket {
    /// A handler that will be executed when this client closes
    ///
    /// Useful for cleaning up
    let onClose: (() -> ())
    
    /// A closure that can be called whenever the socket encountered a critical error
    public var onError: ((Error) -> ())? = nil
    
    /// The maximum amount of data inside `pointer`
    let pointerSize: Int
    
    /// The amount of data currently in `pointer`
    var read = 0
    
    /// A pointer containing a maximum of `self.pointerSize` of data
    let pointer: UnsafeMutablePointer<UInt8>
    
    /// Creates a new Remote Client from the ServerSocket's details
    init(descriptor: Int32, addr: UnsafePointer<sockaddr_storage>, onClose:  @escaping (() -> ())) {
        self.onClose = onClose
        
        // Allocate one TCP packet
        self.pointerSize = 65_507
        self.pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.pointerSize)
        self.pointer.initialize(to: 0, count: self.pointerSize)
        
        super.init(descriptor: descriptor, server: false)
    }
    
    /// Cleans up the client by calling the onClose provded in the initializer and closing the file descriptor
    public override func cleanup() {
        onClose()
        
        super.cleanup()
    }
    
    /// Starts receiving data from the client
    public func listen() {
        self.readSource.setEventHandler {
            #if os(Linux)
                self.read = Glibc.recv(self.descriptor, self.pointer, self.pointerSize, 0)
            #else
                self.read = Darwin.recv(self.descriptor, self.pointer, self.pointerSize, 0)
            #endif
            
            guard self.read > -1 else {
                self.handleError(TCPError.readFailure)
                return
            }
            
            guard self.read != 0 else {
                self.close()
                return
            }
            
            let buffer = UnsafeBufferPointer(start: self.pointer, count: self.read)
            
            for stream in self.branchStreams {
                _ = try? stream(buffer)
            }
        }
        
        self.readSource.resume()
    }
    
    /// Takes care of error handling
    func handleError(_ error: TCPError) {
        self.close()
        
        self.onError?(error)
    }
    
    /// Deallocated the pointer buffer
    deinit {
        pointer.deinitialize(count: self.pointerSize)
        pointer.deallocate(capacity: self.pointerSize)
    }
}
