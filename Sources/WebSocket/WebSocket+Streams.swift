import Core

public final class TextStream : Core.Stream {
    public func inputStream(_ input: String) {
        _ = input.withCString(encodedAs: UTF8.self) { pointer in
            do {
                let mask = self.masking ? randomMask() : nil
                
                let frame = try Frame(op: .text, payload: ByteBuffer(start: pointer, count: input.utf8.count), mask: mask)
                
                frameStream?.inputStream(frame)
            } catch {
                self.errorStream?(error)
            }
        }
    }
    
    public var outputStream: ((String) -> ())?
    
    internal weak var frameStream: Connection?
    
    public var errorStream: BaseStream.ErrorHandler?
    
    public typealias Input = String
    public typealias Output = String
    
    var masking: Bool {
        return frameStream?.serverSide == false
    }
    
    public init() { }
}

public final class BinaryStream : Core.Stream {
    public func inputStream(_ input: ByteBuffer) {
        do {
            let mask = self.masking ? randomMask() : nil
            
            let frame = try Frame(op: .binary, payload: input, mask: mask)
            
            if masking {
                frame.mask()
            }
            
            frameStream?.inputStream(frame)
        } catch {
            self.errorStream?(error)
        }
    }
    
    public var outputStream: ((ByteBuffer) -> ())?
    
    internal weak var frameStream: Connection?
    
    public var errorStream: BaseStream.ErrorHandler?
    
    public typealias Input = ByteBuffer
    public typealias Output = ByteBuffer
    
    let masking: Bool
    
    public init(masking: Bool = false) {
        self.masking = masking
    }
}
