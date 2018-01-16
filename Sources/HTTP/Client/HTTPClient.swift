import Async
import Bits

/// An HTTP client wrapped around TCP client
///
/// Can handle a single `Request` at a given time.
///
/// Multiple requests at the same time are subject to unknown behaviour
///
/// [Learn More →](https://docs.vapor.codes/3.0/http/client/)
public final class HTTPClient {
    /// Inverse stream, takes in responses and outputs requests
    private let queueStream: QueueStream<HTTPResponse, HTTPRequest>

    /// Store the response map here, so it can capture
    /// the sink and source variables.
    private let responseMap: (HTTPResponse) throws -> HTTPResponse

    /// Creates a new Client wrapped around a `TCP.Client`
    public init<Stream>(stream: Stream, on worker: Worker, maxResponseSize: Int = 10_000_000)
        where Stream: ByteStream
    {
        let queueStream = QueueStream<HTTPResponse, HTTPRequest>()

        let serializerStream = HTTPRequestSerializer().stream(on: worker)
        let parserStream = HTTPResponseParser().stream(on: worker)

        stream.stream(to: parserStream)
            .stream(to: queueStream)
            .stream(to: serializerStream)
            .output(to: stream)

        self.responseMap = { res in
            if let onUpgrade = res.onUpgrade {
                try onUpgrade.closure(.init(stream), .init(stream), worker)
            }
            return res
        }

        self.queueStream = queueStream
    }

    /// Sends an HTTP request.
    public func send(_ request: HTTPRequest) -> Future<HTTPResponse> {
        return queueStream.enqueue(request).map(to: HTTPResponse.self) { res in
            return try self.responseMap(res)
        }
    }
}
