     import Async
import Foundation
import Dispatch
import Bits
import TCP

/// Represents an HTTP Message's Body.
///
/// This can contain any data and should match the Message's "Content-Type" header.
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/body/)
public struct HTTPBody: Codable {
    /// The internal storage medium.
    ///
    /// NOTE: This is an implementation detail
    enum Storage: Codable {
        case none
        case data(Data)
        case staticString(StaticString)
        case dispatchData(DispatchData)
        case string(String)
        case chunkedOutputStream(OutputChunkedStreamClosure)
        case binaryOutputStream(size: Int?, stream: AnyOutputStream<ByteBuffer>)
        
        func encode(to encoder: Encoder) throws {
            switch self {
            case .none: return
            case .data(let data):
                try data.encode(to: encoder)
            case .dispatchData(let data):
                try Data(data).encode(to: encoder)
            case .staticString(let string):
                try Data(bytes: string.utf8Start, count: string.utf8CodeUnitCount).encode(to: encoder)
            case .string(let string):
                try string.encode(to: encoder)
            case .chunkedOutputStream(_):
                /// FIXME: properly encode stream
                return
            case .binaryOutputStream(_):
                /// FIXME: properly encode stream
                return
            }
        }
        
        init(from decoder: Decoder) throws {
            self = .data(try Data(from: decoder))
        }
        
        /// The size of this buffer
        var count: Int {
            switch self {
            case .data(let data): return data.count
            case .dispatchData(let data): return data.count
            case .staticString(let staticString): return staticString.utf8CodeUnitCount
            case .string(let string): return string.utf8.count
            case .chunkedOutputStream, .none:
                /// FIXME: convert to data then return count?
                return 0
            case .binaryOutputStream(let size, _):
                return size ?? 0
            }
        }
        
        /// Accesses the bytes of this data
        func withUnsafeBytes<Return>(_ run: ((BytesPointer) throws -> (Return))) throws -> Return {
            switch self {
            case .data(let data):
                return try data.withUnsafeBytes(run)
            case .dispatchData(let data):
                return try data.withUnsafeBytes(body: run)
            case .staticString(let staticString):
                return try run(staticString.utf8Start)
            case .string(let string):
                return try string.withCString { pointer in
                    return try pointer.withMemoryRebound(to: UInt8.self, capacity: self.count, run)
                }
            case .none, .chunkedOutputStream(_), .binaryOutputStream(_):
                throw HTTPError(identifier: "invalid-stream-acccess", reason: "A BodyStream was being accessed as a sequential byte buffer, which is impossible.")
            }
        }
    }
    
    /// The underlying storage type
    var storage: Storage
    
    /// Creates an empty body
    public init() {
        storage = .none
    }
    
    /// Create a new body wrapping `Data`.
    public init(_ data: Data) {
        storage = .data(data)
    }
    
    /// Create a new body wrapping `DispatchData`.
    public init(_ data: DispatchData) {
        storage = .dispatchData(data)
    }
    
    /// Create a new body from the UTF-8 representation of a StaticString
    public init(staticString: StaticString) {
        storage = .staticString(staticString)
    }
    
    /// Create a new body from the UTF-8 representation of a string
    public init(string: String) {
        self.storage = .string(string)
    }
    
    /// Output the body stream to the chunk encoding stream
    /// When supplied in this closure
    typealias OutputChunkedStreamClosure  = (HTTPChunkEncodingStream) -> (HTTPChunkEncodingStream)
    
    /// A chunked body stream
    public init<S>(chunked stream: S) where S: Async.OutputStream, S.Output == ByteBuffer {
        self.storage = .chunkedOutputStream(stream.stream)
    }
    
    /// A chunked body stream
    public init(size: Int?, stream: AnyOutputStream<ByteBuffer>) {
        self.storage = .binaryOutputStream(size: size, stream: stream)
    }
    
    /// Decodes a body from from a Decoder
    public init(from decoder: Decoder) throws {
        self.storage = try Storage(from: decoder)
    }
    
    /// Executes a closure with a pointer to the start of the data
    ///
    /// Can be used to read data from this buffer until the `count`.
    public func withUnsafeBytes<Return>(_ run: ((BytesPointer) throws -> (Return))) throws -> Return {
        return try self.storage.withUnsafeBytes(run)
    }
    
    /// Get body data.
    public func makeData(max: Int) -> Future<Data> {
        switch storage {
        case .none:
            return Future(Data())
        case .data(let data):
            return Future(data)
        case .dispatchData(let dispatch):
            return Future(Data(dispatch))
        case .staticString(let string):
            return Future(Data(bytes: string.utf8Start, count: string.utf8CodeUnitCount))
        case .string(let string):
            return Future(Data(string.utf8))
        case .chunkedOutputStream(_):
            return Future(error: HTTPError(identifier: "chunked-output-stream", reason: "Cannot convert a chunked output stream to a `Data` buffer"))
        case .binaryOutputStream(let size, let stream):
            let promise = Promise<Data>()
            var data = Data()
            
            if let size = size {
                data.reserveCapacity(size)
            }
            
            stream.drain { buffer, upstream in
                data.append(Data(buffer: buffer))
            }.catch(onError: promise.fail).finally {
                promise.complete(data)
            }.request(count: .max)
            
            return promise.future
        }
    }
    
    /// The size of the data buffer
    public var count: Int {
        return self.storage.count
    }
}

/// Can be converted to an HTTP body.
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/body/#bodyrepresentable)
public protocol HTTPBodyRepresentable {
    /// Convert to an HTTP body.
    func makeBody() throws -> HTTPBody
}

/// String can be represented as an HTTP body.
extension String: HTTPBodyRepresentable {
    /// See BodyRepresentable.makeBody()
    public func makeBody() throws -> HTTPBody {
        return HTTPBody(string: self)
    }
}

