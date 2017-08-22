import Core
import TCP

/// An HTTP client wrapped around TCP client
public final class Client: Core.Stream {
    public typealias Input = SerializedMessage
    public typealias Output = ByteBuffer

    public var outputStream: OutputHandler? {
        get {
            return client.outputStream
        }
        set {
            client.outputStream = newValue
        }
    }
    public var errorStream: ErrorHandler?

    public let client: TCP.Client

    public init(client: TCP.Client) {
        self.client = client
    }

    public func inputStream(_ input: SerializedMessage) {
        client.inputStream(input.message)
        input.onUpgrade?(client)
    }
}
