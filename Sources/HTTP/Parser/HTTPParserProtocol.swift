import Transport

public protocol ParserProtocol {
    init(stream: Stream)
    func parse<MessageType: Message>(_ type: MessageType.Type) throws -> MessageType
}
