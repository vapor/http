import struct Base.Bytes

public struct EmailAttachment {
    public let filename: String
    public let contentType: String

    public let body: Bytes

    public init(filename: String, contentType: String, body: Bytes) {
        self.filename = filename
        self.contentType = contentType
        self.body = body
    }
}
