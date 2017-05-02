#if os(OSX)
import Transport
import libc
import Sockets
import Dispatch

public final class AsyncServer: Server {
    public var scheme: String
    public var hostname: String
    public var port: Port
    
    public init() {
        self.scheme = "http"
        self.hostname = "0.0.0.0"
        self.port = 8123
    }
    
    private let queue = DispatchQueue(
        label: "codes.vapor.server",
        qos: .userInteractive,
        attributes: .concurrent
    )
    
    
    public func start(_ responder: Responder, errors: @escaping ServerErrorHandler) throws {
        var len: Int32
        var rc: Int32
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
        rc = fcntl(listen.descriptor.raw, F_SETFL, O_NONBLOCK)
        if (rc < 0)
        {
            perror("fcntl() failed");
            close(listen.descriptor.raw);
            exit(-1);
        }
        
        /*************************************************************/
        /* Bind the socket                                           */
        /*************************************************************/
        try listen.bind()
        
        /*************************************************************/
        /* Set the listen back log                                   */
        /*************************************************************/
        try listen.listen(max: 32)

        
        let group = DispatchGroup()
        group.enter()
        for i in 1...8 {
            print("Starting worker \(i)")
            
            queue.async {
                do {
                    try self.run(listen, i)
                } catch {
                    print("Working \(i) error")
                    errors(.accept(error))
                }
            }
        }
        group.wait()
    }
    
    public func run(_ listen: TCPInternetSocket, _ worker: Int) throws {
        var len: Int32
        var rc: Int32
        var on: Int32 = 1
        
        var max_sd: Int32
        var new_sd: Int32
        
        var desc_ready: Int32
        var end_server: Int32 = 0;
        
        var close_conn: Int32
        var buffer = Array<CChar>(repeating: 0, count: 4096)
        // var addr = sockaddr()
        var timeout = timeval()
        var master_set = fd_set()
        var working_set = fd_set()
        
        /*************************************************************/
        /* Initialize the master fd_set                              */
        /*************************************************************/
        fdZero(&master_set);
        max_sd = listen.descriptor.raw;
        fdSet(listen.descriptor.raw, &master_set);
        
        /*************************************************************/
        /* Initialize the timeval struct to 3 minutes.  If no        */
        /* activity after 3 minutes this program will end.           */
        /*************************************************************/
        timeout.tv_sec  = 3 * 60;
        timeout.tv_usec = 0;
        
        /*************************************************************/
        /* Loop waiting for incoming connects or for incoming data   */
        /* on any of the connected sockets.                          */
        /*************************************************************/
        repeat
        {
            /**********************************************************/
            /* Copy the master fd_set over to the working fd_set.     */
            /**********************************************************/
            working_set = master_set
            
            /**********************************************************/
            /* Call select() and wait 5 minutes for it to complete.   */
            /**********************************************************/
            // print("Worker \(worker) waiting on select()...");
            // print("Waiting for select on worker \(worker)")
            rc = select(max_sd + 1, &working_set, nil, nil, &timeout);
            
            /**********************************************************/
            /* Check to see if the select call failed.                */
            /**********************************************************/
            if (rc < 0)
            {
                if errno == EINTR {
                    continue
                }
                perror("  select() failed");
                break;
            }
            
            /**********************************************************/
            /* Check to see if the 5 minute time out expired.         */
            /**********************************************************/
            if (rc == 0)
            {
                print("  select() timed out.  End program.\n");
                break;
            }
            
            /**********************************************************/
            /* One or more descriptors are readable.  Need to         */
            /* determine which ones they are.                         */
            /**********************************************************/
            desc_ready = rc;
            var i: Int32 = 0
            // for (i=0; i <= max_sd  &&  desc_ready > 0; ++i)
            while(i <= max_sd  &&  desc_ready > 0) {
                i += 1
                /*******************************************************/
                /* Check to see if this descriptor is ready            */
                /*******************************************************/
                if (fdIsSet(i, &working_set))
                {
                    /****************************************************/
                    /* A descriptor was found that was readable - one   */
                    /* less has to be looked for.  This is being done   */
                    /* so that we can stop looking at the working set   */
                    /* once we have found all of the descriptors that   */
                    /* were ready.                                      */
                    /****************************************************/
                    desc_ready -= 1;
                    
                    /****************************************************/
                    /* Check to see if this is the listening socket     */
                    /****************************************************/
                    if (i == listen.descriptor.raw)
                    {
                        // print("  Listening socket is readable\n");
                        /*************************************************/
                        /* Accept all incoming connections that are      */
                        /* queued up on the listening socket before we   */
                        /* loop back and call select again.              */
                        /*************************************************/
                        repeat
                        {
                            /**********************************************/
                            /* Accept each incoming connection.  If       */
                            /* accept fails with EWOULDBLOCK, then we     */
                            /* have accepted all of them.  Any other      */
                            /* failure on accept will cause us to end the */
                            /* server.                                    */
                            /**********************************************/
                            // print("before accept")
                            new_sd = accept(listen.descriptor.raw, nil, nil);
                            if (new_sd < 0)
                            {
                                if (errno != EWOULDBLOCK)
                                {
                                    perror("  accept() failed");
                                    end_server = 1;
                                }
                                break;
                            }
                            
                            /**********************************************/
                            /* Add the new incoming connection to the     */
                            /* master read set                            */
                            /**********************************************/
                            // print("  New incoming connection - \(new_sd) on worker \(worker)\n");
                            fdSet(new_sd, &master_set);
                            if (new_sd > max_sd) {
                                max_sd = new_sd;
                            }
                            
                            /**********************************************/
                            /* Loop back up and accept another incoming   */
                            /* connection                                 */
                            /**********************************************/
                        } while (new_sd != -1);
                    }
                        
                        /****************************************************/
                        /* This is not the listening socket, therefore an   */
                        /* existing connection must be readable             */
                        /****************************************************/
                    else
                    {
                        // print("  Descriptor \(i) is readable\n");
                        close_conn = 0;
                        /*************************************************/
                        /* Receive all incoming data on this socket      */
                        /* before we loop back and call select again.    */
                        /*************************************************/
                        repeat
                        {
                            /**********************************************/
                            /* Receive data on this connection until the  */
                            /* recv fails with EWOULDBLOCK.  If any other */
                            /* failure occurs, we will close the          */
                            /* connection.                                */
                            /**********************************************/
                            rc = Int32(recv(i, &buffer, 4096, 0))
                            if (rc < 0)
                            {
                                if (errno != EWOULDBLOCK)
                                {
                                    perror("  recv() failed");
                                    close_conn = 1;
                                }
                                break;
                            }
                            
                            /**********************************************/
                            /* Check to see if the connection has been    */
                            /* closed by the client                       */
                            /**********************************************/
                            if (rc == 0)
                            {
                                // print("  Connection closed\n");
                                close_conn = 1;
                                break;
                            }
                            
                            /**********************************************/
                            /* Data was received                          */
                            /**********************************************/
                            len = rc;
                            // print(rc.description)
                            // print("  \(len) bytes received\n");
                            // print(String(validatingUTF8: buffer) ?? "")
                            
                            /**********************************************/
                            /* Echo the data back to the client           */
                            /**********************************************/
                            
                            // print("Sending on worker \(worker)")
                            
                            var res = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 13\r\n\r\nHello, world!".makeBytes()
                            
                            rc = Int32(send(i, &res, res.count, 0))
                            if (rc < 0)
                            {
                                perror("  send() failed");
                                close_conn = 1;
                                break;
                            }
                            
                        } while (true);
                        
                        /*************************************************/
                        /* If the close_conn flag was turned on, we need */
                        /* to clean up this active connection.  This     */
                        /* clean up process includes removing the        */
                        /* descriptor from the master set and            */
                        /* determining the new maximum descriptor value  */
                        /* based on the bits that are still turned on in */
                        /* the master set.                               */
                        /*************************************************/
                        if (close_conn == 1)
                        {
                            close(i);
                            fdClr(i, &master_set);
                            if (i == max_sd)
                            {
                                while (fdIsSet(max_sd, &master_set) == false) {
                                    max_sd -= 1;
                                }
                            }
                        }
                    } /* End of existing connection is readable */
                } /* End of if (FD_ISSET(i, &working_set)) */
            } /* End of loop through selectable descriptors */
            
        } while (end_server == 0);
        
        /*************************************************************/
        /* Clean up all of the sockets that are open                  */
        /*************************************************************/
        var j: Int32 = 0
        while (j <= max_sd) {
            if (fdIsSet(j, &master_set)) {
                close(j);
            }
            j += 1
        }
    }
}
#endif
