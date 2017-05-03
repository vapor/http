import Dispatch
import Sockets

class AsyncServerWorker<Stream: DuplexStream & DescriptorRepresentable> {
    var id: Int
    var queue: DispatchQueue
    var buffer: Bytes
    
    let serializer: ResponseSerializer
    let parser: RequestParser
    let responder: AsyncResponder
    
    var connected: [Int32: DispatchSourceRead]
    
    init(id: Int, _ responder: AsyncResponder) {
        self.id = id
        self.responder = responder
        
        self.queue = DispatchQueue(label: "codes.vapor.server.worker.\(id)")
        self.buffer = Bytes(repeating: 0, count: 4096)
        self.serializer = ResponseSerializer()
        self.parser = RequestParser()
        
        connected = [:]
    }
    
    func accept(
        _ client: Stream
    ) throws {
        let fd = client.makeDescriptor().raw
        let readSource = DispatchSource.makeReadSource(
            fileDescriptor: fd,
            queue: queue
        )
        connected[fd] = readSource
        
        readSource.setEventHandler {
            try! self.onDataAvailable(client)
        }
        
        readSource.resume()
    }
    
    private func onDataAvailable(
        _ client: Stream
    ) throws {
        let fd = client.makeDescriptor().raw
        guard let readSource = connected[fd] else {
            return
        }
        
        let read: Int
        do {
            read = try client.read(max: buffer.count, into: &buffer)
        } catch {
            readSource.cancel()
            connected[fd] = nil
            throw error
        }
        
        if read == 0 {
            readSource.cancel()
            connected[fd] = nil
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
