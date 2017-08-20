import Core
import Dispatch
import Foundation

public final class ResponseSerializer: Serializer {
    // MARK: Stream
    public typealias Input = Response
    public typealias Output = DispatchData
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?

    public init() {}

    public func inputStream(_ input: Response) {
        let data = serialize(input)
        outputStream?(data)
    }

    public func serialize(_ response: Response) -> DispatchData {
        var serialized = serialize(response.status)

        let iterator = response.headers.makeIterator()
        while let header = iterator.next() {
            let data = serialize(header: header.name, value: header.value)
            serialized.append(data)
        }
        serialized.append(eol)

        let body = serialize(response.body)
        serialized.append(body)

        return serialized
    }

    private func serialize(_ status: Status) -> DispatchData {
        switch status {
        case .upgrade:
            return Signature.upgrade
        case .ok:
            return Signature.ok
        case .notFound:
            return Signature.notFound
        case .internalServerError:
            return Signature.internalServerError
        case .custom(let code, let message):
            return DispatchData("HTTP/1.1 \(code.description) \(message.utf8)\r\n")
        }
    }

    private func serialize(header name: Headers.Name, value: String) -> DispatchData {
        return DispatchData("\(name): \(value)\r\n")
    }

    private func serialize(_ body: Body) -> DispatchData {
        let pointer: BytesPointer = body.data.withUnsafeBytes { $0 }
        let bodyRaw = UnsafeRawBufferPointer(
            start: UnsafeRawPointer(pointer),
            count: body.data.count
        )
        return DispatchData(bytes: bodyRaw)
    }
}

// MARK: Utilities

fileprivate let eol = DispatchData("\r\n")
fileprivate enum Signature {
    static let internalServerError = DispatchData("HTTP/1.1 500 Internal Server Error\r\n")
    static let upgrade = DispatchData("HTTP/1.1 101 Switching Protocols\r\n")
    static let ok = DispatchData("HTTP/1.1 200 OK\r\n")
    static let notFound = DispatchData("HTTP/1.1 404 Not Found\r\n")
}

extension DispatchData {
    init(_ string: String) {
        self.init(bytes: string.unsafeRawBufferPointer)
    }
}

extension String {
    var unsafeRawBufferPointer: UnsafeRawBufferPointer {
        let data = self.data(using: .utf8) ?? Data()
        return data.withUnsafeBytes { pointer in
            return UnsafeRawBufferPointer(start: pointer, count: data.count)
        }
    }
}
