import Core

public final class FrameParser : Core.Stream {
    static func decodeFrameHeader(from base: UnsafePointer<UInt8>, length: Int) throws -> (final: Bool, op: Frame.OpCode, size: UInt64, mask: [UInt8], consumed: Int) {
        guard
            length > 3,
            let code = Frame.OpCode(rawValue: base[0] & 0b00001111),
            base[1] & 0b10000000 == 0b10000000 else {
                throw WebSocketError.invalidFrame
        }
        
        // If the FIN bit is set
        let final = base[0] & 0b10000000 == 0b10000000
        
        // Extract the payload bits
        var payloadLength = UInt64(base[1] & 0b01111111)
        var consumed = 2
        var base = base.advanced(by: 2)
        
        // Binary and continuation frames don't need to be final
        if !final {
            guard code == .continuation || code == .binary else {
                throw WebSocketError.invalidFrame
            }
        }
        
        // Ping and pong cannot have a bigger payload than tihs
        if code == .ping || code == .pong {
            guard payloadLength < 126 else {
                throw WebSocketError.invalidFrame
            }
        }
        
        // Parse the payload length as UInt16 following the 126
        if payloadLength == 126 {
            guard length >= 5 else {
                throw WebSocketError.invalidFrame
            }
            
            payloadLength = base.withMemoryRebound(to: UInt16.self, capacity: 1, { UInt64($0.pointee) })
            
            base = base.advanced(by: 2)
            consumed = consumed &+ 2
            
        // payload length byte == 127 means it's followed by a UInt64
        } else if payloadLength == 127 {
            guard length >= 11 else {
                throw WebSocketError.invalidFrame
            }
            
            payloadLength = base.withMemoryRebound(to: UInt64.self, capacity: 1, { $0.pointee })
            
            base = base.advanced(by: 8)
            consumed = consumed &+ 8
        }
        
        guard length &- consumed == payloadLength &+ 4, payloadLength < Int.max else {
            throw WebSocketError.invalidFrame
        }
        
        let mask = [base[0], base[1], base[2], base[3]]
        base = base.advanced(by: 4)
        consumed = consumed &+ 4
        
        return (final, code, payloadLength, mask, consumed)
    }
}


//let length = numericCast(header.payloadLength) as Int
//let data = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
//
//for i in 0..<length {
//    data[i] = base[i] ^ mask[i % 4]
//}

