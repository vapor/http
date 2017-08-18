import Streams
import libc

typealias RequestParsedHandler = ((Request)->())

fileprivate let contentLengthKey: HeaderKey = "Content-Length"

/// The request crafter
///
/// Receives data asynchronously and reads the data in the pointer until it's completely read a request
internal final class HTTPParser : Stream {
    /// Creates a new placeholder
    init() { }
    
    /// The pointer in which the pointer is moved
    var pointer: UnsafePointer<UInt8>!
    
    /// The remaining length of data behind the pointer
    var length: Int!
    
    /// The current offset from the pointer
    var currentPosition: Int = 0
    
    /// If false, parsing failed and it needs to wait until the next package anymore
    ///
    /// This puts the remaining data in the leftovers
    ///
    /// TODO: Use leftovers for parsing
    var parsable = true {
        didSet {
            if parsable == false {
                self.leftovers.append(contentsOf: UnsafeBufferPointer(start: pointer, count: length))
                return
            }
        }
    }
    
    /// If true, parsing can proceed
    fileprivate var proceedable: Bool {
        return correct && parsable
    }
    
    /// Defines whether the HTTP Request is correct
    var correct = true
    
    /// The leftover buffer from previous parsing attempts
    var leftovers = [UInt8]()
    
    /// If `true`, the first line of HTTP is parsed
    var topLineComplete = false
    
    /// If true, all components of a request have been parsed
    var complete = false
    
    /// The request's HTTP Method
    var method: Method?
    
    /// The request's path, including the query
    var path: Path?
    
    /// All of the requests headers
    var headers: Headers?
    
    /// The full length of the body, including all that hasn't been received yet
    var contentLength = 0
    
    /// The currently copiedbodyLength
    var bodyLength = 0
    
    /// A buffer in which the body is kept
    var body: UnsafeMutablePointer<UInt8>?
    
    /// Cleans up the RequestPlaceholder for a next request
    func empty() {
        self.method = nil
        self.path = nil
        self.headers = nil
        self.topLineComplete = false
        self.complete = false
        self.correct = true
        self.parsable = true
        self.contentLength = 0
        self.bodyLength = 0
        self.body = nil
    }
    
    /// Parses the data at the pointer to proceed building the request
    func parse(_ buffer: UnsafeBufferPointer<UInt8>) -> Request? {
        guard let ptr = buffer.baseAddress else {
            return nil
        }
        
        self.pointer = ptr
        self.length = buffer.count
        
        func parseMethod() {
            pointer.peek(until: 0x20, length: &length, offset: &currentPosition)
            
            // length + 1
            if currentPosition == 4 {
                if ptr[0] == 0x47, ptr[1] == 0x45, ptr[2] == 0x54 {
                    self.method = .get
                    return
                }
                
                if ptr[0] == 0x50, ptr[1] == 0x55, ptr[2] == 0x54 {
                    self.method = .put
                    return
                }
            } else if currentPosition == 5 {
                if ptr[0] == 0x50, ptr[1] == 0x4f, ptr[2] == 0x53, ptr[3] == 0x54 {
                    self.method = .post
                    return
                }
            } else if currentPosition == 6 {
                if ptr[0] == 0x50, ptr[1] == 0x41, ptr[2] == 0x54, ptr[3] == 0x43, ptr[4] == 0x48 {
                    self.method = .patch
                    return
                }
            } else if currentPosition == 7 {
                if ptr[0] == 0x44, ptr[1] == 0x45, ptr[2] == 0x4c, ptr[3] == 0x45, ptr[4] == 0x54, ptr[5] == 0x45 {
                    self.method = .delete
                    return
                }
            } else if currentPosition == 8 {
                if ptr[0] == 0x4f, ptr[1] == 0x50, ptr[2] == 0x54, ptr[3] == 0x49, ptr[4] == 0x4f, ptr[5] == 0x4e, ptr[6] == 0x53 {
                    self.method = .options
                    return
                }
            }
            
            guard let string = pointer.string(until: &currentPosition) else {
                parsable = false
                return
            }
            
            // Can't be precalculated
            self.method = .other(string)
        }
        
        func parsePath() {
            pointer.peek(until: 0x20, length: &length, offset: &currentPosition)
            
            let buffer = pointer.buffer(until: &currentPosition)
            
            // '?'
            if let index = buffer.index(of: 0x3f), index &+ 1 < buffer.count {
                let path = UnsafeBufferPointer(start: buffer.baseAddress, count: index)
                let query = UnsafeBufferPointer(start: buffer.baseAddress?.advanced(by: index &+ 1), count: buffer.count &- index &- 2)
                
                self.path = Path(path: path, query: query)
            } else {
                self.path = Path(path: UnsafeBufferPointer(start: buffer.baseAddress, count: buffer.count &- 1), query: nil)
            }
        }
        
        func parseHeaders() {
            let start = pointer
            
            while true {
                // \n
                pointer.peek(until: 0x0a, length: &length, offset: &currentPosition)
                
                guard currentPosition > 0 else {
                    self.headers = Headers()
                    return
                }
                
                if length > 1, pointer[-2] == 0x0d, pointer[0] == 0x0d, pointer[1] == 0x0a {
                    defer {
                        pointer = pointer.advanced(by: 2)
                        length = length &- 2
                    }
                    
                    self.headers = Headers(serialized: UnsafeBufferPointer(start: start, count: start!.distance(to: pointer)))
                    return
                }
            }
        }
        
        guard buffer.count > 7 else {
            return nil
        }
        
        if proceedable, method == nil {
            parseMethod()
        }
        
        if proceedable, path == nil {
            parsePath()
        }
        
        if proceedable, !topLineComplete {
            pointer.peek(until: 0x0a, length: &length, offset: &currentPosition)
            
            guard pointer[-2] == 0x0d else {
                correct = false
                return nil
            }
            
            topLineComplete = true
        }
        
        if proceedable, headers == nil {
            parseHeaders()
            
            if let cl = headers?[contentLengthKey], let contentLength = Int(cl.rawValue) {
                self.contentLength = contentLength
                let body = UnsafeMutablePointer<UInt8>.allocate(capacity: self.contentLength)
                body.initialize(to: 0, count: self.contentLength)
                self.body = body
            }
        }
        
        if length > 0, let body = body {
            let copiedLength = min(length, contentLength &- bodyLength)
            memcpy(body.advanced(by: bodyLength), pointer, copiedLength)
            length = length &- copiedLength
            self.bodyLength = bodyLength &+ copiedLength
            pointer = pointer.advanced(by: copiedLength)
        }
        
        defer {
            leftovers.append(contentsOf: UnsafeBufferPointer(start: pointer, count: length))
        }
        
        if bodyLength == contentLength, let request = self.makeRequest() {
            defer {
                self.empty()
            }
            
            return request
        }
        
        return nil
    }
    
    func map<T>(_ closure: @escaping ((Request) throws -> (T?))) -> StreamTransformer<Request, T> {
        let stream = StreamTransformer<Output, T>(using: closure)
        
        branchStreams.append(stream.process)
        
        return stream
    }
    
    public typealias Output = Request
    
    /// Internal typealias used to define a cascading callback
    typealias ProcessOutputCallback = ((Output) throws -> ())
    
    /// All entities waiting for a new packet
    var branchStreams = [ProcessOutputCallback]()
    
    deinit {
        body?.deallocate(capacity: self.contentLength)
    }
    
    /// Whenn all of the request's components have been read, this creates a Request object
    func makeRequest() -> Request? {
        guard let method = method, let path = path, let headers = headers else {
            return nil
        }
        
        return Request(method: method, path: path, headers: headers, body: UnsafeMutableBufferPointer(start: body, count: contentLength))
    }
}

// MARK - Copy for swift inline optimization

extension UnsafePointer where Pointee == UInt8 {
    fileprivate func string(until length: inout Int) -> String? {
        return String(bytes: buffer(until: &length), encoding: .utf8)
    }
    
    fileprivate func buffer(until length: inout Int) -> UnsafeBufferPointer<UInt8> {
        guard length > 0 else {
            return UnsafeBufferPointer<UInt8>(start: nil, count: 0)
        }
        
        return UnsafeBufferPointer(start: self.advanced(by: -length), count: length)
    }
    
    fileprivate mutating func peek(until byte: UInt8, length: inout Int!, offset: inout Int) {
        offset = 0
        defer { length = length &- offset }
        
        while offset &+ 4 < length {
            if self[0] == byte {
                offset = offset &+ 1
                self = self.advanced(by: 1)
                return
            }
            if self[1] == byte {
                offset = offset &+ 2
                self = self.advanced(by: 2)
                return
            }
            if self[2] == byte {
                offset = offset &+ 3
                self = self.advanced(by: 3)
                return
            }
            offset = offset &+ 4
            defer { self = self.advanced(by: 4) }
            if self[3] == byte {
                return
            }
        }
        
        if offset < length, self[0] == byte {
            offset = offset &+ 1
            self = self.advanced(by: 1)
            return
        }
        if offset &+ 1 < length, self[1] == byte {
            offset = offset &+ 2
            self = self.advanced(by: 2)
            return
        }
        if offset &+ 2 < length, self[2] == byte {
            offset = offset &+ 3
            self = self.advanced(by: 3)
            return
        }
        
        self = self.advanced(by: length &- offset)
        offset = length
    }
}
