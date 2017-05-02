import Transport
import libc
import Sockets
import Dispatch

private var res = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 13\r\n\r\nHello, world!".makeBytes()

public final class DispatchSyncServer: Server {
    public var scheme: String
    public var hostname: String
    public var port: Port
    
    //    var queues: [Queue] = []
    public init() {
        self.scheme = "http"
        self.hostname = "0.0.0.0"
        self.port = 8123
        //        for i in 1...8 {
        //            print("Creating queue \(i)")
        //            let queue = Queue(
        //                DispatchQueue(label: "codes.vapor.server.worker.\(i)", qos: .userInteractive),
        //                Array<Byte>(repeating: 0, count: 4096)
        //            )
        //            queues.append(queue)
        //        }
    }
    
    var queue = DispatchQueue(label: "codes.vapor.server", qos: .userInteractive, attributes: .concurrent)
    
    public func start(_ responder: Responder, errors: @escaping ServerErrorHandler) throws {
        let listen = try TCPInternetSocket(port: self.port)
        
        /*************************************************************/
        /* Create an AF_INET stream socket to receive incoming       */
        /* connections on                                            */
        /*************************************************************/
        //        listen_sd = socket(AF_INET, SOCK_STREAM, 0);
        //        if (listen_sd < 0)
        //        {
        //            perror("socket() failed");
        //            exit(-1);
        //        }
        
        /*************************************************************/
        /* Allow socket descriptor to be reuseable                   */
        /*************************************************************/
        //        rc = setsockopt(listen_sd, SOL_SOCKET,  SO_REUSEADDR, &on, socklen_t(MemoryLayout<Int>.stride)); // FIXME
        //        if (rc < 0)
        //        {
        //            perror("setsockopt() failed");
        //            close(listen_sd);
        //            exit(-1);
        //        }
        
        /*************************************************************/
        /* Set socket to be nonblocking. All of the sockets for    */
        /* the incoming connections will also be nonblocking since  */
        /* they will inherit that state from the listening socket.   */
        /*************************************************************/
        
        
        /*************************************************************/
        /* Bind the socket                                           */
        /*************************************************************/
        try listen.bind()
        
        /*************************************************************/
        /* Set the listen back log                                   */
        /*************************************************************/
        try listen.listen(max: 32)
        
        try self.run(listen)
    }
    
    
    public func run(_ listen: TCPInternetSocket) throws {
        while true {
            let client = accept(listen.descriptor.raw, nil, nil)
            
            queue.async {
                while true {
                    var readBuffer = Array<Byte>(repeating: 0, count: 4096)
                    
                    var rc = recv(client, &readBuffer, readBuffer.capacity, 0)
                    if (rc < 0)
                    {
                        if (errno != EWOULDBLOCK)
                        {
                            perror("  recv() failed");
                            return
                        }
                    }
                    
                    
                    if (rc == 0)
                    {
                        // print("  Connection closed\n");
                        close(client)
                        break
                    }
                    
                    // print("Writing data to \(client)")
                    rc = send(client, &res, res.count, 0)
                    if (rc < 0)
                    {
                        perror("  send() failed");
                        return
                    }
                }
            }
        }
    }
}
