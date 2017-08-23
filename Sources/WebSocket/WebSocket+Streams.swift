import Core

public final class TextStream : Core.Stream {
    public func inputStream(_ input: String) {
        _ = input.withCString(encodedAs: UTF8.self) { pointer in
            do {
                let frame = try Frame(op: .text, payload: ByteBuffer(start: pointer, count: input.utf8.count), mask: randomMask(), isMasked: false)
                
                if masking {
                    frame.mask()
                }
                
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
    
    let masking: Bool
    
    func randomMask() -> [UInt8]? {
        // TODO: Generate for masking clients
        
        return nil
    }
    
    public init(masking: Bool = false) {
        self.masking = masking
    }
}

public final class BinaryStream : Core.Stream {
    public func inputStream(_ input: ByteBuffer) {
        do {
            let frame = try Frame(op: .binary, payload: input, mask: randomMask(), isMasked: false)
            
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
    
    func randomMask() -> [UInt8]? {
        // TODO: Generate for masking clients
        
        return nil
    }
    
    public init(masking: Bool = false) {
        self.masking = masking
    }
}
