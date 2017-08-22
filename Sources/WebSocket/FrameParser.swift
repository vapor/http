import Core

public final class FrameParser : Core.Stream {
    public typealias Input = ByteBuffer
    public typealias Output = Frame
    
    public var outputStream: OutputHandler?
    public var errorStream: ErrorHandler?
    
    public func inputStream(_ input: ByteBuffer) {
        guard let pointer = input.baseAddress else {
            // ignore
            return
        }
        
        func processBuffer(header: Frame.Header, buffer: ByteBuffer) {
            defer {
                self.processing = nil
            }
            
            do {
                let frame = try Frame(op: header.op, payload: buffer, mask: header.mask, isMasked: header.mask != nil)
                
                self.outputStream?(frame)
            } catch {
                errorStream?(error)
            }
        }
        
        if let (header, offset) = processing {
            let total = Int(header.size)
            
            if offset + input.count >= total {
                let consume = total &- offset
                
                bufferBuilder.advanced(by: offset).assign(from: pointer, count: consume)
                
                processBuffer(header: header, buffer: ByteBuffer(start: bufferBuilder, count: total))
                
                self.inputStream(ByteBuffer(start: pointer.advanced(by: consume), count: input.count &- consume))
            } else {
                bufferBuilder.advanced(by: offset).assign(from: pointer, count: input.count)
            }
        } else {
            guard let header = try? FrameParser.decodeFrameHeader(from: pointer, length: input.count) else {
                self.partialBuffer += Array(input)
                return
            }
            
            guard header.size < UInt64(self.maximumPayloadSize) else {
                self.errorStream?(Error(.invalidBufferSize))
                return
            }
            
            let pointer = pointer.advanced(by: header.consumed)
            let remaining = input.count &- header.consumed
            
            guard Int(header.size) <= remaining else {
                bufferBuilder.assign(from: pointer, count: input.count)
                self.processing = (header, input.count)
                return
            }
            
            processBuffer(header: header, buffer: ByteBuffer(start: pointer, count: Int(header.size)))
        }
    }
    
    deinit {
        bufferBuilder.deallocate(capacity: maximumPayloadSize + 15)
    }
    
    let bufferBuilder: MutableBytesPointer
    let maximumPayloadSize: Int
    
    var partialBuffer = [UInt8]()
    var processing: (Frame.Header, Int)?
    
    public init(maximumPayloadSize: Int = 10_000_000) {
        self.maximumPayloadSize = maximumPayloadSize
        // 2 for the header, 9 for the length, 4 for the mask
        self.bufferBuilder = MutableBytesPointer.allocate(capacity: maximumPayloadSize + 15)
    }
    
    static func decodeFrameHeader(from base: UnsafePointer<UInt8>, length: Int) throws -> Frame.Header {
        guard
            length > 3,
            let code = Frame.OpCode(rawValue: base[0] & 0b00001111),
            base[1] & 0b10000000 == 0b10000000 else {
                throw Error(.invalidFrame)
        }
        
        // If the FIN bit is set
        let final = base[0] & 0b10000000 == 0b10000000
        
        // Extract the payload bits
        var payloadLength = UInt64(base[1] & 0b01111111)
        let isMasked = base[1] & 0b10000000 == 0b10000000
        var consumed = 2
        var base = base.advanced(by: 2)
        
        // Binary and continuation frames don't need to be final
        if !final {
            guard code == .continuation || code == .binary else {
                throw Error(.invalidFrameParameters)
            }
        }
        
        // Ping and pong cannot have a bigger payload than tihs
        if code == .ping || code == .pong {
            guard payloadLength < 126 else {
                throw Error(.invalidFrame)
            }
        }
        
        // Parse the payload length as UInt16 following the 126
        if payloadLength == 126 {
            guard length >= 5 else {
                throw Error(.invalidFrame)
            }
            
            payloadLength = base.withMemoryRebound(to: UInt16.self, capacity: 1, { UInt64($0.pointee) })
            
            base = base.advanced(by: 2)
            consumed = consumed &+ 2
            
        // payload length byte == 127 means it's followed by a UInt64
        } else if payloadLength == 127 {
            guard length >= 11 else {
                throw Error(.invalidFrame)
            }
            
            payloadLength = base.withMemoryRebound(to: UInt64.self, capacity: 1, { $0.pointee })
            
            base = base.advanced(by: 8)
            consumed = consumed &+ 8
        }
        
        guard length &- consumed == payloadLength &+ 4, payloadLength < Int.max else {
            throw Error(.invalidFrame)
        }
        
        let mask: [UInt8]?
        
        if isMasked {
            guard consumed &+ 4 < length else {
                throw Error(.invalidMask)
            }
            
            mask = [base[0], base[1], base[2], base[3]]
            base = base.advanced(by: 4)
            consumed = consumed &+ 4
        } else {
            mask = nil
        }
        
        return (final, code, payloadLength, mask, consumed)
    }
}
