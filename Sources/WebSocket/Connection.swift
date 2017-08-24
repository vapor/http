import Core
import Dispatch
import HTTP
import TCP

internal final class Connection: Core.Stream {
    internal typealias Input = Frame
    internal typealias Output = Frame

    var outputStream: OutputHandler?
    var errorStream: ErrorHandler?
    
    let serializer: FrameSerializer
    
    let serverSide: Bool

    let client: TCP.Client
    init(client: TCP.Client, serverSide: Bool = true) {
        self.client = client
        self.serverSide = serverSide
        
        let parser = FrameParser()
        serializer = FrameSerializer(masking: !serverSide)
        
        client.stream(to: parser).drain { frame in
            self.outputStream?(frame)
        }
        
        serializer.drain { buffer in
            let buffer = UnsafeRawBufferPointer(buffer)
            client.inputStream(DispatchData(bytes: buffer))
        }
    }

    func inputStream(_ input: Frame) {
        serializer.inputStream(input)
    }
}
