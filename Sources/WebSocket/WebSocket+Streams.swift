import Core

public final class TextStream : Core.Stream {
    public func inputStream(_ input: String) {
        do {
            _ = try input.withCString(encodedAs: UTF8.self) { pointer in
                try frameStream?.sendFrame(opcode: .text, pointer: pointer, length: input.utf8.count)
            }
        } catch {
            self.errorStream?(error)
        }
    }
    
    public var outputStream: ((String) -> ())?
    
    internal weak var frameStream: Connection?
    
    public var errorStream: BaseStream.ErrorHandler?
    
    public typealias Input = String
    public typealias Output = String
    
    init() {}
}

public final class BinaryStream : Core.Stream {
    public func inputStream(_ input: ByteBuffer) {
        guard let pointer = input.baseAddress else {
            return
        }
        
        do {
            try frameStream?.sendFrame(opcode: .binary, pointer: pointer, length: input.count)
        } catch {
            self.errorStream?(error)
        }
    }
    
    public var outputStream: ((ByteBuffer) -> ())?
    
    internal weak var frameStream: Connection?
    
    public var errorStream: BaseStream.ErrorHandler?
    
    public typealias Input = ByteBuffer
    public typealias Output = ByteBuffer
    
    init() {}
}
