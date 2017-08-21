import Core
import TCP

internal final class Connection : Core.Stream {
    func inputStream(_ input: Frame) {
        client.drain { buffer in
            guard let pointer = buffer.baseAddress else {
                return
            }
            
            do {
                let frame = try Frame(from: pointer, length: buffer.count)
                self.outputStream?(frame)
            } catch {
                self.client.errorStream?(error)
            }
        }
    }
    
    var outputStream: ((Frame) -> ())?
    
    let message = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(UInt16.max))
    
    var errorStream: BaseStream.ErrorHandler?
    
    internal typealias Input = Frame
    internal typealias Output = Frame
    
    init(client: Client) {
        self.client = client
    }
    
    let client: Client
}
