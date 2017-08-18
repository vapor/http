fileprivate let decodeLookupTable: [UInt8] = [
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 62, 64, 62, 64, 63,
    52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 64, 64, 64, 64, 64, 64,
    64, 00, 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14,
    15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 64, 64, 64, 64, 63,
    64, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
    64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64, 64,
]

fileprivate let encodeTable = [UInt8]("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)

extension Base64Stream.Mode {
    fileprivate func encode(_ buffer: UnsafeBufferPointer<UInt8>, toPointer pointer: UnsafeMutablePointer<UInt8>, capacity: Int) -> (complete: Bool, filled: Int, consumed: Int) {
        guard let input = buffer.baseAddress else {
            return (true, 0, 0)
        }
        
        var inputPosition = 0
        var outputPosition = 0
        var processedByte: UInt8
        
        func byte(at pos: UInt8) -> UInt8 {
            return encodeTable[numericCast(pos)]
        }
        
        while inputPosition < buffer.count, outputPosition &+ 4 < capacity {
            defer {
                inputPosition = inputPosition &+ 3
                outputPosition = outputPosition &+ 4
            }
            
            pointer[outputPosition] = byte(at: (input[inputPosition] & 0xfc) >> 2)
            
            processedByte = (input[inputPosition] & 0x03) << 4
            
            guard inputPosition &+ 1 < buffer.count else {
                pointer[outputPosition &+ 1] = byte(at: processedByte)
                
                // '=='
                pointer[outputPosition &+ 2] = 0x3d
                pointer[outputPosition &+ 3] = 0x3d
                
                return (true, outputPosition &+ 4, inputPosition &+ 1)
            }
            
            processedByte |= (input[inputPosition &+ 1] & 0xf0) >> 4
            pointer[outputPosition &+ 1] = byte(at: processedByte)
            processedByte = (input[inputPosition &+ 1] & 0x0f) << 2
            
            guard inputPosition &+ 2 < buffer.count else {
                pointer[outputPosition &+ 2] = byte(at: processedByte)
                
                // '='
                pointer[outputPosition &+ 3] = 0x3d
                return (true, outputPosition &+ 4, inputPosition &+ 2)
            }
            
            processedByte |= (input[inputPosition &+ 2] & 0xc0) >> 6
            pointer[outputPosition &+ 2] = byte(at: processedByte)
            pointer[outputPosition &+ 3] = byte(at: input[inputPosition &+ 2] & 0x3f)
        }
        
        return (inputPosition == buffer.count, outputPosition, inputPosition)
    }
    
    fileprivate func decode(_ buffer: UnsafeBufferPointer<UInt8>, toPointer: UnsafeMutablePointer<UInt8>, capacity: Int) -> (complete: Bool, filled: Int, consumed: Int) {
        guard let input = buffer.baseAddress else {
            return (true, 0, 0)
        }
        
        fatalError()
    }
    
    // returns complete
    public func process(_ buffer: UnsafeBufferPointer<UInt8>, to stream: Base64Stream) -> (complete: Bool, consumed: Int) {
        switch self {
        case .encoding:
            let (complete, capacity, consumed) = encode(buffer, toPointer: stream.pointer, capacity: stream.allocatedCapacity)
            stream.currentCapacity = capacity
            return (complete, consumed)
        case .decoding:
            let (complete, capacity, consumed) = decode(buffer, toPointer: stream.pointer, capacity: stream.allocatedCapacity)
            stream.currentCapacity = capacity
            return (complete, consumed)
        }
    }
}
