public enum HTTPMessageError: Error {
    case invalidStartLine
}

public class HTTPMessage {
    public let startLine: String
    public var headers: [HeaderKey: String]

    // Settable for HEAD request -- evaluate alternatives -- Perhaps serializer should handle it.
    // must NOT be exposed public because changing body will break behavior most of time
    public var body: HTTPBody

    public var storage: [String: Any] = [:]

    public convenience required init(
        startLineComponents: (BytesSlice, BytesSlice, BytesSlice),
        headers: [HeaderKey: String],
        body: HTTPBody
    ) throws {
        var startLine = startLineComponents.0.string
        startLine += " "
        startLine += startLineComponents.1.string
        startLine += " "
        startLine += startLineComponents.2.string

        self.init(startLine: startLine, headers: headers,body: body)
    }

    public init(startLine: String, headers: [HeaderKey: String], body: HTTPBody) {
        self.startLine = startLine
        self.headers = headers
        self.body = body
    }
}

extension HTTPMessage: TransferMessage {}

extension HTTPMessage {
    public var contentType: String? {
        return headers["Content-Type"]
    }
    public var keepAlive: Bool {
        // HTTP 1.1 defaults to true unless explicitly passed `Connection: close`
        guard let value = headers["Connection"] else { return true }
        return !value.contains("close")
    }
}
