/// Specifies an HTTP transport-layer scheme.
#warning("consider using tlsConfig option like HTTPServer")
public struct HTTPScheme {
    /// Plaintext data over TCP. Uses port `80` by default.
    public static var http: HTTPScheme {
        return .init(80) { $0.eventLoop.makeSucceededFuture(result: ()) }
    }

    /// Enables TLS (SSL). Uses port `443` by default.
    public static var https: HTTPScheme {
        return .init(443) { channel in
            do {
                let tlsConfiguration = TLSConfiguration.forClient(certificateVerification: .none)
                let sslContext = try SSLContext(configuration: tlsConfiguration)
                let tlsHandler = try OpenSSLClientHandler(context: sslContext)
                return channel.pipeline.add(handler: tlsHandler)
            } catch {
                return channel.eventLoop.makeFailedFuture(error: error)
            }
        }
    }

    /// See `ws`.
    public static let ws: HTTPScheme = .http

    /// See `https`.
    public static let wss: HTTPScheme = .https

    /// The default port to use for this scheme if no override is provided.
    public let defaultPort: Int

    /// Internal callback for configuring a client channel.
    /// This should be expanded with server support at some point.
    internal let configureChannel: (Channel) -> EventLoopFuture<Void>

    /// Internal initializer, end users will take advantage of pre-defined static variables.
    internal init(_ defaultPort: Int, configureChannel: @escaping (Channel) -> EventLoopFuture<Void>) {
        self.defaultPort = defaultPort
        self.configureChannel = configureChannel
    }
}
