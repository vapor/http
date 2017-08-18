import Foundation

/// A response's body
///
/// Crafted from a mutable buffer pointer that can be deallocated
public class Body : Codable {
    /// Decodes the body from binary data
    public required init(from decoder: Decoder) throws {
        let data = try decoder.singleValueContainer().decode(Data.self)
        
        let pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        
        _ = data.withUnsafeBytes { dataBuffer in
            pointer.initialize(from: dataBuffer, count: data.count)
        }
        
        self.buffer = UnsafeMutableBufferPointer(start: pointer, count: data.count)
        self.deallocate = true
    }
    
    public convenience init(_ writer: ((((UnsafeBufferPointer<UInt8>) throws -> ()))->())) throws {
        var array = [UInt8]()
        
        writer { buffer in
            array.append(contentsOf: buffer)
        }
        
        self.init(array)
    }
    
    /// Encodes the body to binary Data
    public func encode(to encoder: Encoder) throws {
        var encoder = encoder.singleValueContainer()
        try encoder.encode(Data(buffer))
    }
    
    /// The buffer with data to be returned to the client
    public let buffer: UnsafeMutableBufferPointer<UInt8>
    
    /// If true, deallocates the buffer on deinit of the body
    public let deallocate: Bool
    
    /// Creates a new body for a Response from a buffer pointer
    ///
    /// - parameter buffer: The buffer to respond with
    /// - parameter deallocating: If true, deallocate the provided buffer
    public init(pointingTo buffer: UnsafeMutableBufferPointer<UInt8>, deallocating: Bool) {
        self.buffer = buffer
        self.deallocate = deallocating
    }
    
    public convenience init(_ array: [UInt8]) {
        let allocated = UnsafeMutablePointer<UInt8>.allocate(capacity: array.count)
        allocated.initialize(from: array, count: array.count)
        
        let buffer = UnsafeMutableBufferPointer<UInt8>(start: allocated, count: array.count)
        
        self.init(pointingTo: buffer, deallocating: true)
    }
    
    deinit {
        if deallocate {
            buffer.baseAddress?.deallocate(capacity: buffer.count)
        }
    }
}

/// Anything that can be representative of a Request or aaResponse Body
public protocol BodyRepresentable {
    /// Creates a body
    func makeBody() throws -> Body
    
    /// Useful for writing the body in chunks, reducing memory usage
    func write(_ writer: ((UnsafeBufferPointer<UInt8>) throws -> ())) throws
}

/// A common file protocol
///
/// Useful for file uploading, receiving fileuploads, file storage and mail attachments
public protocol File : BodyRepresentable {
    var name: String { get }
    var mimeType: String { get }
}

extension BodyRepresentable {
    /// Writes the entire body's data in one go
    public func write(_ writer: ((UnsafeBufferPointer<UInt8>) throws -> ())) throws {
        let body = try self.makeBody()
        
        let buffer = UnsafeBufferPointer(start: body.buffer.baseAddress, count: body.buffer.count)
        
        try writer(buffer)
    }
}

/// Makes Body representative of a body (thus itself)
extension Body : BodyRepresentable {
    /// Creates a body from itself
    public func makeBody() throws -> Body {
        return self
    }
}

/// Makes String representative of a body
extension String : BodyRepresentable {
    /// Creates a body containing exclusively this String
    public func makeBody() throws -> Body {
        let allocated = UnsafeMutablePointer<UInt8>.allocate(capacity: self.utf8.count)
        allocated.initialize(from: [UInt8](self.utf8), count: self.utf8.count)
        
        let buffer = UnsafeMutableBufferPointer<UInt8>(start: allocated, count: self.utf8.count)
        
        return Body(pointingTo: buffer, deallocating: true)
    }
}

