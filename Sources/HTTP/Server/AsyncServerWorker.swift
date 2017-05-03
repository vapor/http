import Dispatch
import Sockets

class AsyncServerWorker<Stream: DuplexStream & DescriptorRepresentable> {
    var id: Int
    var queue: DispatchQueue
    var buffer: Bytes
    
    let serializer: ResponseSerializer
    let parser: RequestParser
    let responder: Responder
    
    init(id: Int, _ responder: Responder) {
        self.id = id
        self.responder = responder
        
        self.queue = DispatchQueue(label: "codes.vapor.server.worker.\(id)")
        self.buffer = Bytes(repeating: 0, count: 4096)
        self.serializer = ResponseSerializer()
        self.parser = RequestParser()
    }
    
    func accept(
        _ client: Stream
    ) throws {
        let read = DispatchSource.makeReadSource(
            fileDescriptor: client.makeDescriptor().raw,
            queue: queue
        )
        
        read.setEventHandler {
            try! self.onDataAvailable(read, client)
        }
        
        read.setCancelHandler {}
        read.resume()
    }
    
    private func onDataAvailable(
        _ readSource: DispatchSourceRead,
        _ client: Stream
    ) throws {
        let read: Int
        do {
            read = try client.read(max: buffer.count, into: &buffer)
        } catch {
            readSource.cancel()
            throw error
        }
        
        if read == 0 {
            readSource.cancel()
        }
        
        guard let request = try parser.parse(
            max: read,
            from: buffer
        ) else {
            // will try again when more data is available
            return
        }
        
        try responder.respond(to: request) { response in
            while true {
                let length = try self.serializer.serialize(response, into: &self.buffer)
                
                guard length > 0 else {
                    break
                }
                
                let written = try client.write(max: length, from: self.buffer)
                guard written == length else {
                    // FIXME: better error
                    print("Not all bytes were written")
                    throw StreamError.closed
                }
            }
            
            switch response.body {
            case .chunked(let closure):
                let chunk = ChunkStream(client)
                try closure(chunk)
            default:
                break
            }
        }

    }
}
