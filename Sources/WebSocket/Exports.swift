@_exported import HTTP
@_exported import NIO
@_exported import NIOWebSocket

extension FixedWidthInteger {
    static var anyRandom: Self {
        return self.random(in: Self.min..<Self.max)
    }
}
