import libc
import Core

public final class FrameSerializer : Core.Stream {
    public typealias Input = Frame
    
    // TODO: Is this a good idea?
    public typealias Output = ByteBuffer
    
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    public func inputStream(_ input: Frame) {
        let final: Byte = input.final ? 0b10000000 : 0
        let maskBit: Byte = input.mask == nil ? 0 : 0b10000000
        let maskSize = input.mask == nil ? 0 : 4
        
        let message: MutableBytesPointer
        let outputSize: Int
        var offset = 0
        
        if input.payloadLength < 126 {
            outputSize = input.payloadLength &+ 2 &+ maskSize
            message = MutableBytesPointer.allocate(capacity: outputSize)
            // header + mask
            
            message[0] = final | input.opCode.rawValue
            message[1] = maskBit | numericCast(input.payloadLength)
            
            offset = 2
        } else if input.payloadLength <= Int(UInt16.max) {
            outputSize = input.payloadLength &+ 4 &+ maskSize
            message = MutableBytesPointer.allocate(capacity: outputSize)
            
            message[0] = final | input.opCode.rawValue
            message[1] = maskBit | 126
            var payloadLength: UInt16 = numericCast(input.payloadLength)
            
            memcpy(message.advanced(by: 2), &payloadLength, 2)
            
            offset = 4
        } else {
            outputSize = input.payloadLength &+ 10 &+ maskSize
            message = MutableBytesPointer.allocate(capacity: outputSize)
            
            message[0] = final | input.opCode.rawValue
            message[1] = maskBit | 127
            
            var payloadLength: UInt64 = numericCast(input.payloadLength)
            memcpy(message.advanced(by: 2), &payloadLength, 8)
            
            offset = 10
        }
        
        message.advanced(by: offset).assign(from: mes, count: <#T##Int#>)
        
        _ = try client.socket.write(max: drained &+ extra, from: ByteBuffer(start: message, count: drained &+ extra))
        return drained
    }
}
