
// It doesn't work :( -- infinite loop

///**
//    This is a quasi-default generics implementation so a user can simply do:
// 
//         HTTPServer(host: ...
// 
//    and it will be equivelant to:
// 
//        HTTPServer<TCPServerStream, HTTPParser<HTTPRequest>, HTTPSerializer<HTTPResponse>>(host: ...
// 
//    This allows most common use case to be inferred but still extendible for the explorers
//*/
//extension HTTPServer where ServerStreamType: TCPServerStream, Parser: HTTPParser<HTTPRequest>, Serializer: HTTPSerializer<HTTPResponse> {
//    public convenience init(host: String = "0.0.0.0", port: Int = 8080, securityLayer: SecurityLayer = .none) throws {
//        try self.init(host: host, port: port, securityLayer: securityLayer)
//    }
//}
////
