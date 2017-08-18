public final class Base64Stream : Stream {
    public typealias Output = UnsafeBufferPointer<UInt8>
    
    let allocatedCapacity: Int
    var currentCapacity = 0
    let pointer: UnsafeMutablePointer<UInt8>
    let mode: Mode
    
    public enum Mode {
        case encoding, decoding
    }
    
    public init(allocatedCapacity: Int = 65_507, mode: Mode) {
        self.allocatedCapacity = (allocatedCapacity * 4) / 3
        self.pointer = UnsafeMutablePointer<UInt8>.allocate(capacity: self.allocatedCapacity)
        self.pointer.initialize(to: 0, count: self.allocatedCapacity)
        self.mode = mode
    }
    
    /// Transforms the incoming data
    public func process(_ input: UnsafeBufferPointer<UInt8>) throws {
        var input = input
        var complete: Bool
        var consumed: Int
        
        repeat {
            (complete, consumed) = self.mode.process(input, to: self)
            input = UnsafeBufferPointer(start: input.baseAddress?.advanced(by: consumed), count: input.count - consumed)
            
            for stream in branchStreams {
                try stream(UnsafeBufferPointer(start: pointer, count: self.currentCapacity))
            }
        } while !complete
    }
    
    public func map<T>(_ closure: @escaping ((Output) throws -> (T?))) -> StreamTransformer<Base64Stream.Output, T> {
        let stream = StreamTransformer<Output, T>(using: closure)
        
        branchStreams.append(stream.process)
        
        return stream
    }
    
    /// Internal typealias used to define a cascading callback
    fileprivate typealias ProcessOutputCallback = ((Output) throws -> ())
    
    /// An internal array, used to keep track of all closures waiting for more data from this stream
    fileprivate var branchStreams = [ProcessOutputCallback]()
    
    /// Deallocated the pointer buffer
    deinit {
        pointer.deinitialize(count: self.allocatedCapacity)
        pointer.deallocate(capacity: self.allocatedCapacity)
    }
}
