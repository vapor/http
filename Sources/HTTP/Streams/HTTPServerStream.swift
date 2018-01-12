//import Async
//import Bits
//
///// Accepts a stream of byte streams converting them to client stream.
//internal final class HTTPServerStream<AcceptStream, Worker>: InputStream
//    where AcceptStream: OutputStream,
//    AcceptStream.Output: ByteStreamRepresentable,
//    Worker: HTTPResponder,
//    Worker: Async.Worker
//{
//    /// See InputStream.Input
//    typealias Input = AcceptStream.Output
//
//    /// Handles errors
//    internal var onError: HTTPServer<AcceptStream, Worker>.ErrorHandler?
//
//    /// The upstream accept stream
//    private var upstream: ConnectionContext?
//
//    /// HTTP responder
//    private let worker: Worker
//
//    /// Create a new HTTP server stream.
//    init(
//        acceptStream: AcceptStream,
//        worker: Worker
//    ) {
//        self.worker = worker
//        acceptStream.output(to: self)
//    }
//
//    /// See InputStream.input
//    func input(_ event: InputEvent<AcceptStream.Output>) {
//        switch event {
//        case .connect(let upstream):
//            /// never stop accepting
//            upstream.request(count: .max)
//        case .next(let input):
//            let serializerStream = HTTPResponseSerializer().stream(on: worker)
//            let parserStream = HTTPRequestParser().stream(on: worker)
//
//            let source = input.source(on: worker)
//            let sink = input.sink(on: worker)
//            source
//                .stream(to: parserStream)
//                .stream(to: worker.stream(on: worker).stream())
//                .map(to: HTTPResponse.self) { response in
//                    /// map the responder adding http upgrade support
//                    defer {
//                        if let onUpgrade = response.onUpgrade {
//                            do {
//                                try onUpgrade.closure(.init(source), .init(sink), self.worker)
//                            } catch {
//                                self.onError?(error)
//                            }
//                        }
//                    }
//                    return response
//                }
//                .stream(to: serializerStream)
//                .output(to: sink)
//        case .error(let error):
//            onError?(error)
//        case .close: print("Accept stream closed.")
//        }
//    }
//}

