import Core
import TCP

internal final class Connection : Core.Stream {
    func inputStream(_ input: Frame) {
        do {
            try self.sendFrame(input)
        } catch {
            self.errorStream?(error)
        }
    }
    
    var outputStream: ((Frame) -> ())?
    
    var errorStream: BaseStream.ErrorHandler?
    
    internal typealias Input = Frame
    internal typealias Output = Frame
    
    init(client: Client) {
        self.client = client
        
        let parser = FrameParser()
        
        client.stream(to: parser).drain { frame in
            outputStream?(frame)
        }
    }
    
    let client: Client
}
