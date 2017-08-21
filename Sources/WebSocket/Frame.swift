import Core

/// Frame format:
///
///  0                   1                   2                   3
///  0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
/// +-+-+-+-+-------+-+-------------+-------------------------------+
/// |F|R|R|R| opcode|M| Payload len |    Extended payload length    |
/// |I|S|S|S|  (4)  |A|     (7)     |             (16/64)           |
/// |N|V|V|V|       |S|             |   (if payload len==126/127)   |
/// | |1|2|3|       |K|             |                               |
/// +-+-+-+-+-------+-+-------------+ - - - - - - - - - - - - - - - +
/// |     Extended payload length continued, if payload len == 127  |
/// + - - - - - - - - - - - - - - - +-------------------------------+
/// |                               |Masking-key, if MASK set to 1  |
/// +-------------------------------+-------------------------------+
/// | Masking-key (continued)       |          Payload Data         |
/// +-------------------------------- - - - - - - - - - - - - - - - +
/// :                     Payload Data continued ...                :
/// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
/// |                     Payload Data continued ...                |
/// +---------------------------------------------------------------+
internal final class Frame {
    enum OpCode: Byte {
        case continuation = 0x00
        case text = 0x01
        case binary = 0x02
        
        case close = 0x08
        case ping = 0x09
        case pong = 0x0a
    }
    
    let final: Bool
    let opCode: OpCode
    let data: MutableByteBuffer
    
    init(from base: UnsafePointer<UInt8>, length: Int) throws {
        guard
            length > 3,
            let code = OpCode(rawValue: base[0] & 0b00001111),
            base[1] & 0b10000000 == 0b10000000 else {
                throw WebSocketError.invalidFrame
        }
        
        // If the FIN bit is set
        final = base[0] & 0b10000000 == 0b10000000
        self.opCode = code
        
        // Extract the payload bits
        var payloadLength = UInt64(base[1] & 0b01111111)
        var consumed = 2
        var base = base.advanced(by: 2)
        
        if !final {
            guard code == .continuation || code == .binary else {
                throw WebSocketError.invalidFrame
            }
        }
        
        if code == .ping || code == .pong {
            guard payloadLength < 126 else {
                throw WebSocketError.invalidFrame
            }
        }
        
        if payloadLength == 126 {
            payloadLength = base.withMemoryRebound(to: UInt16.self, capacity: 1, { UInt64($0.pointee) })
            
            base = base.advanced(by: 2)
            consumed = consumed &+ 2
        } else if payloadLength == 127 {
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
        
        let length = numericCast(payloadLength) as Int
        let data = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        
        for i in 0..<length {
            data[i] = base[i] ^ mask[i % 4]
        }
        
        self.data = UnsafeMutableBufferPointer(start: data, count: length)
    }
    
    deinit {
        data.baseAddress?.deallocate(capacity: data.count)
    }
}

public enum WebSocketError : Error {
    case invalidFrame
    case invalidUpgrade
    case couldNotConnect
    case invalidBuffer
}
