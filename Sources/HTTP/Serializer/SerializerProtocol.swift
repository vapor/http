import Transport

public protocol SerializerProtocol {
    init(stream: Stream)
    func serialize(_ message: Message) throws
}
