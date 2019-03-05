@_exported import NIO
@_exported import NIOExtras
@_exported import NIOHTTPCompression
@_exported import NIOHTTP2
@_exported import NIOHTTP1
@_exported import NIOSSL
@_exported import NIOWebSocket

extension FixedWidthInteger {
    static var anyRandom: Self {
        return Self.random(in: Self.min..<Self.max)
    }
}

extension HTTPRequestEncoder: RemovableChannelHandler { }
extension HTTPResponseCompressor: RemovableChannelHandler { }
