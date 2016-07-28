public enum MessageError: Error {
    case invalidStartLine
}

public class Message {
    public let startLine: String
    public var headers: [HeaderKey: String]

    // Settable for HEAD request -- evaluate alternatives -- Perhaps serializer should handle it.
    // must NOT be exposed public because changing body will break behavior most of time
    public var body: Body

    public var storage: [String: Any] = [:]

    public convenience required init(
        startLineComponents: (BytesSlice, BytesSlice, BytesSlice),
        headers: [HeaderKey: String],
        body: Body
    ) throws {
        var startLine = startLineComponents.0.string
        startLine += " "
        startLine += startLineComponents.1.string
        startLine += " "
        startLine += startLineComponents.2.string

        self.init(startLine: startLine, headers: headers,body: body)
    }

    public init(startLine: String, headers: [HeaderKey: String], body: Body) {
        self.startLine = startLine
        self.headers = headers
        self.body = body
    }
}

extension Message: TransferMessage {}

extension Message {
    public var contentType: String? {
        return headers["Content-Type"]
    }
    public var keepAlive: Bool {
        // HTTP 1.1 defaults to true unless explicitly passed `Connection: close`
        guard let value = headers["Connection"] else { return true }
        return !value.contains("close")
    }
}
