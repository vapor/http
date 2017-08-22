import Dispatch
import Core
import TCP

internal final class Connection : Core.Stream {
    func inputStream(_ input: Frame) {
        serializer.inputStream(input)
    }
    
    var outputStream: ((Frame) -> ())?
    
    var errorStream: BaseStream.ErrorHandler?
    
    internal typealias Input = Frame
    internal typealias Output = Frame
    
    let serializer = FrameSerializer()
    
    init(client: Client) {
        self.client = client
        
        let parser = FrameParser()
        
        client.stream(to: parser).drain { frame in
            self.outputStream?(frame)
        }
        
        serializer.drain { buffer in
            let buffer = UnsafeRawBufferPointer(buffer)
            client.inputStream(DispatchData(bytes: buffer))
        }
    }
    
    let client: Client
}
