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
    /// The underlying storage type
    var storage: HTTPBodyStorage

    /// Internal HTTPBody init with underlying storage type.
    internal init(storage: HTTPBodyStorage) {
        self.storage = storage
    }

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
    
    /// A chunked body stream
    public init<S>(chunked stream: S) where S: Async.OutputStream, S.Output == ByteBuffer {
        self.storage = .chunkedOutputStream(stream.stream)
    }
    
    /// A chunked body stream
    public init(stream: AnyOutputStream<ByteBuffer>, count: @escaping () -> Int?) {
        self.storage = .binaryOutputStream(count: count, stream: stream)
    }
    
    /// Decodes a body from from a Decoder
    public init(from decoder: Decoder) throws {
        self.storage = try HTTPBodyStorage(from: decoder)
    }
    
    /// Executes a closure with a pointer to the start of the data
    ///
    /// Can be used to read data from this buffer until the `count`.
    public func withUnsafeBytes<Return>(_ run: (ByteBuffer) throws -> Return) throws -> Return {
        return try self.storage.withUnsafeBytes(run)
    }
    
    /// Get body data.
    public func makeData(max: Int) -> Future<Data> {
        return storage.makeData(max: max)
    }
    
    /// The size of the data buffer
    public var count: Int? {
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

extension HTTPBody: CustomStringConvertible {
    /// See `CustomStringConvertible.description
    public var description: String {
        switch storage {
        case .binaryOutputStream: return "<binary output stream> (use `debugPrint(_:)` to consume)"
        case .chunkedOutputStream: return "<chunked output stream> (use `debugPrint(_:)` to consume)"
        case .data, .buffer, .dispatchData, .none, .staticString, .string: return debugDescription
        }
    }
 }

extension HTTPBody: CustomDebugStringConvertible {
    /// See `CustomDebugStringConvertible.debugDescription`
    public var debugDescription: String {
        switch storage {
        case .buffer(let buffer): return String(bytes: buffer, encoding: .ascii) ?? "n/a"
        case .data(let data): return String(data: data, encoding: .ascii) ?? "n/a"
        case .dispatchData(let data): return String(data: Data(data), encoding: .ascii) ?? "n/a"
        case .none: return "<empty>"
        case .staticString(let string): return string.description
        case .string(let string): return string
        case .chunkedOutputStream, .binaryOutputStream:
            do {
                let data = try makeData(max: 2048).blockingAwait(timeout: .seconds(5))
                let string = String(data: data, encoding: .ascii) ?? "Error: Decoding body data as ASCII failed."
                return "<output stream consumed> " + string
            } catch {
                return "Error collecting body data: \(error)"
            }
        }
    }
 }

/// Output the body stream to the chunk encoding stream
/// When supplied in this closure
typealias OutputChunkedStreamClosure  = (HTTPChunkEncodingStream) -> (HTTPChunkEncodingStream)

/// The internal storage medium.
///
/// NOTE: This is an implementation detail
enum HTTPBodyStorage: Codable {
    case none
    case buffer(ByteBuffer)
    case data(Data)
    case staticString(StaticString)
    case dispatchData(DispatchData)
    case string(String)
    case chunkedOutputStream(OutputChunkedStreamClosure)
    case binaryOutputStream(count: () -> Int?, stream: AnyOutputStream<ByteBuffer>)

    /// See `Encodable.encode(to:)`
    func encode(to encoder: Encoder) throws {
        switch self {
        case .none: return
        case .data(let data): try data.encode(to: encoder)
        case .buffer(let buffer): try Data(buffer).encode(to: encoder)
        case .dispatchData(let data): try Data(data).encode(to: encoder)
        case .staticString(let string): try Data(bytes: string.utf8Start, count: string.utf8CodeUnitCount).encode(to: encoder)
        case .string(let string): try string.encode(to: encoder)
        case .chunkedOutputStream, .binaryOutputStream:
            throw HTTPError(
                identifier: "streamingBody",
                reason: "A BodyStream cannot be encoded with `encode(to:)`."
            )
        }
    }

    /// See `Decodable.init(from:)`
    init(from decoder: Decoder) throws {
        self = .data(try Data(from: decoder))
    }

    /// The size of the HTTP body's data.
    /// `nil` of the body is a non-determinate stream.
    var count: Int? {
        switch self {
        case .data(let data): return data.count
        case .dispatchData(let data): return data.count
        case .staticString(let staticString): return staticString.utf8CodeUnitCount
        case .string(let string): return string.utf8.count
        case .buffer(let buffer): return buffer.count
        case .none: return 0
        case .chunkedOutputStream: return nil
        case .binaryOutputStream(let size, _): return size()
        }
    }

    /// Accesses the bytes of this data
    func withUnsafeBytes<Return>(_ run: (ByteBuffer) throws -> Return) throws -> Return {
        switch self {
        case .data(let data):
            return try data.withByteBuffer(run)
        case .dispatchData(let data):
            let data = Data(data)
            return try data.withByteBuffer(run)
        case .staticString(let staticString):
            return staticString.withUTF8Buffer { buffer in
                return try! run(buffer) // FIXME: throwing
            }
        case .string(let string):
            let buffer = string.withCString { pointer in
                return ByteBuffer(
                    start: pointer.withMemoryRebound(to: UInt8.self, capacity: string.utf8.count) { $0 },
                    count: string.utf8.count
                )
            }
            return try run(buffer)
        case .buffer(let buffer):
            return try run(buffer)
        case .none:
            return try run(ByteBuffer(start: nil, count: 0))
        case .chunkedOutputStream(_), .binaryOutputStream(_):
            throw HTTPError(
                identifier: "streamingBody",
                reason: "A BodyStream was being accessed as a sequential byte buffer, which is impossible."
            )
        }
    }

    func makeData(max: Int) -> Future<Data> {
        switch self {
        case .none: return Future(Data())
        case .buffer(let buffer): return Future(Data(buffer))
        case .data(let data): return Future(data)
        case .dispatchData(let dispatch): return Future(Data(dispatch))
        case .staticString(let string): return Future(Data(bytes: string.utf8Start, count: string.utf8CodeUnitCount))
        case .string(let string): return Future(Data(string.utf8))
        case .chunkedOutputStream(_):
            let error = HTTPError(
                identifier: "chunkedBody",
                reason: "Cannot use `makeData(max:)` on a chunk-encoded body."
            )
            return Future(error: error)
        case .binaryOutputStream(let size, let stream):
            let promise = Promise<Data>()
            let size = size() ?? 0
            var data = Data()
            data.reserveCapacity(size)

            let drain = DrainStream(ByteBuffer.self, onInput: { buffer in
                guard data.count + buffer.count <= size else {
                    throw HTTPError(identifier: "bodySize", reason: "The body was larger than the request.")
                }

                guard data.count + buffer.count <= max else {
                    throw HTTPError(identifier: "bodySize", reason: "The body was larger than the limit")
                }

                data.append(Data(buffer: buffer))
            }, onError: promise.fail, onClose: {
                promise.complete(data)
            })
            stream.output(to: drain)
            return promise.future
        }
    }
 }
