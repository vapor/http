import Core

public final class FrameSerializer : Core.Stream {
    public typealias Input = Frame
    public typealias Output = ByteBuffer
    
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    public func inputStream(_ input: Frame) {
        let drained: Int
        let extra: Int
        
        message[2] = mask?.0 ?? 0
        message[3] = mask?.1 ?? 0
        message[4] = mask?.2 ?? 0
        message[5] = mask?.3 ?? 0
        
        let maskBit: UInt8 = mask == nil ? 0b00000000 : 0b01000000
        
        if length < 126 {
            // header + mask
            extra = (mask == nil) ? 2 : 6
            
            message[0] = 0b10000000 | opcode.rawValue | maskBit
            message[1] = numericCast(length)
            
            memcpy(message.advanced(by: extra), pointer, length)
            drained = length
        } else if opcode == .text && length > 65_532 {
            // header + UInt64 + mask
            extra = (mask == nil) ? 10 : 14
            
            message[0] = 0b10000000 | opcode.rawValue | maskBit
            message[1] = 0b01111111
            var payloadLength = UInt64(length)
            
            memcpy(message.advanced(by: 2), &payloadLength, 8)
            
            memcpy(message.advanced(by: extra), pointer, length)
            
            return length
        } else {
            // header + UInt16 + mask
            extra = (mask == nil) ? 4 : 6
            
            let final: UInt8 = (length <= Int(UInt16.max) && opcode != .text) ? 0b10000000 : 0b00000000
            
            message[0] = final | opcode.rawValue | maskBit
            message[1] = 0b01111110
            
            drained = min(length, 65_532)
            var payloadLength: UInt16 = numericCast(drained)
            memcpy(message.advanced(by: 2), &payloadLength, 2)
            
            memcpy(message.advanced(by: extra), pointer, drained)
        }
        
        _ = try client.socket.write(max: drained &+ extra, from: ByteBuffer(start: message, count: drained &+ extra))
        return drained
    }
}
