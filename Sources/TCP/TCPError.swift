///// Encapsulates all possible TCP errors
//public enum TCPError : Error {
//    /// Reserving a socket failed
//    ///
//    /// This usually occurs when the socket's port was already taken by a process, or because there are too many open sockets
//    ///
//    /// For a server socket, ensure there are no other processes running on that port or stop them.
//    ///
//    /// Otherwise, use `ulimit -n <integer>` to set the maximum amount of sockets to the amount specified.
//    ///
//    /// The default ulimit is 256.
//    case bindFailure
//    
//    /// Sending a message over TCP failed
//    ///
//    /// Likely because the socket was closed due to either party disconnecting or losing connection.
//    case sendFailure
//    
//    // TODO: Fill out the docs here
//    
//    case readFailure
//}

