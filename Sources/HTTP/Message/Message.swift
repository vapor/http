public protocol Message: class, Codable {
    var version: Version { get set }
    var headers: Headers { get set }
    var body: Body { get set }
}

extension Message {
    internal func updateContentLength() {
        headers[.contentLength] = body.data.count.description
    }
}
