import Foundation
import Dispatch

/// Represents an HTTP Message's Body.
///
/// This can contain any data and should match the Message's "Content-Type" header.
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/body/)
public struct HTTPBody {
    /// The underlying storage type
    var storage: HTTPBodyStorage

    /// Internal HTTPBody init with underlying storage type.
    internal init(storage: HTTPBodyStorage) {
        self.storage = storage
    }

    /// Create a new body wrapping `Data`.
    public init(data: Data) {
        storage = .data(data)
    }

    /// Create a new body wrapping `DispatchData`.
    public init(dispatchData: DispatchData) {
        storage = .dispatchData(dispatchData)
    }

    /// Create a new body from the UTF-8 representation of a StaticString
    public init(staticString: StaticString) {
        storage = .staticString(staticString)
    }

    /// Create a new body from the UTF-8 representation of a string
    public init(string: String) {
        self.storage = .string(string)
    }

    /// Get body data.
    public var data: Data? {
        return storage.data
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
        case .data, .buffer, .dispatchData, .staticString, .string: return debugDescription
        }
    }
}

extension HTTPBody: CustomDebugStringConvertible {
    /// See `CustomDebugStringConvertible.debugDescription`
    public var debugDescription: String {
        switch storage {
        case .buffer(let buffer): return buffer.getString(at: 0, length: buffer.readableBytes) ?? "n/a"
        case .data(let data): return String(data: data, encoding: .ascii) ?? "n/a"
        case .dispatchData(let data): return String(data: Data(data), encoding: .ascii) ?? "n/a"
        case .staticString(let string): return string.description
        case .string(let string): return string
        }
    }
}

/// The internal storage medium.
///
/// NOTE: This is an implementation detail
enum HTTPBodyStorage {
    case buffer(ByteBuffer)
    case data(Data)
    case staticString(StaticString)
    case dispatchData(DispatchData)
    case string(String)

    /// The size of the HTTP body's data.
    /// `nil` of the body is a non-determinate stream.
    var count: Int? {
        switch self {
        case .data(let data): return data.count
        case .dispatchData(let data): return data.count
        case .staticString(let staticString): return staticString.utf8CodeUnitCount
        case .string(let string): return string.utf8.count
        case .buffer(let buffer): return buffer.readableBytes
        }
    }

    var data: Data? {
        switch self {
        case .buffer(let buffer): return buffer.getData(at: 0, length: buffer.readableBytes)
        case .data(let data): return data
        case .dispatchData(let dispatch): return Data(dispatch)
        case .staticString(let string): return Data(bytes: string.utf8Start, count: string.utf8CodeUnitCount)
        case .string(let string): return Data(string.utf8)
        }
    }
}
