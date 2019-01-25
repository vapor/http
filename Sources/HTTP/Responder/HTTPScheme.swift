/// Specifies an HTTP transport-layer scheme.
public struct HTTPScheme {
    /// Plaintext data over TCP. Uses port `80` by default.
    public static var http: HTTPScheme {
        return .init(80) { channel, _ in .done(on: channel.eventLoop) }
    }

    /// Enables TLS (SSL). Uses port `443` by default.
    public static var https: HTTPScheme {
        return self.customHTTPS(.forClient())
    }
    
    /// Enables TLS (SSL) with custom TLS configuration. Uses port `443` by default.
    public static func customHTTPS(_ config: TLSConfiguration) -> HTTPScheme {
        return .init(443) { channel, hostname in
            return Future.flatMap(on: channel.eventLoop) {
                let sslContext = try SSLContext(configuration: config)
                let sniName = hostname.isIPAddress() ? nil : hostname
                let tlsHandler = try OpenSSLClientHandler(context: sslContext, serverHostname: sniName)
                return channel.pipeline.add(handler: tlsHandler)
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
    internal let configureChannel: (Channel, String) -> Future<Void>

    /// Internal initializer, end users will take advantage of pre-defined static variables.
    internal init(_ defaultPort: Int, configureChannel: @escaping (Channel, String) -> Future<Void>) {
        self.defaultPort = defaultPort
        self.configureChannel = configureChannel
    }
}
