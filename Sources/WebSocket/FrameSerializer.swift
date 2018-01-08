import COperatingSystem
import Async
import Bits

/// Serializes frames to binary
final class FrameSerializer: Async.ByteSerializerStream {
    // Unused
    typealias SerializationState = ()
    
    typealias Input = Frame
    typealias Output = ByteBuffer
    
    var state: ByteSerializerStreamState<FrameSerializer>
    var serializing: Frame?
    let masking: Bool
    
    init(masking: Bool) {
        self.state = .init()
        self.masking = masking
    }
    
    func serialize(_ input: Frame, state: ()?) -> ByteSerializerStreamResult<FrameSerializer> {
        if masking {
            input.mask()
        } else {
            input.unmask()
        }
        
        self.serializing = input
        
        return .complete(ByteBuffer(start: input.buffer.baseAddress, count: input.buffer.count))
    }
}

/// Generates a random mask for client sockets
func randomMask() -> [UInt8] {
    var buffer: [UInt8] = [0,0,0,0]
    
    var number: UInt32
    
    #if os(Linux)
        number = numericCast(COperatingSystem.random() % Int(UInt32.max))
    #else
        number = arc4random_uniform(UInt32.max)
    #endif
    
    memcpy(&buffer, &number, 4)
    
    return buffer
}

