import Core
import Dispatch
import Foundation

public final class RequestSerializer: Serializer {
    // MARK: Stream
    public typealias Input = Request
    public typealias Output = DispatchData
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?

    public init() {}

    public func inputStream(_ input: Request) {
        let data = serialize(input)
        outputStream?(data)
    }

    public func serialize(_ request: Request) -> DispatchData {
        var serialized = serialize(method: request.method, uri: request.uri)

        let iterator = request.headers.makeIterator()
        while let header = iterator.next() {
            let data = serialize(header: header.name, value: header.value)
            serialized.append(data)
        }
        serialized.append(eol)

        let body = serialize(request.body)
        serialized.append(body)

        return serialized
    }

    private func serialize(method: Method, uri: URI) -> DispatchData {
        return DispatchData("\(method.string) \(uri.path) HTTP/1.1\r\n")
    }
}
