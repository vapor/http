import Transport

extension URI {
    /// Default ports known to correspond with given schemes.
    /// Expand as possible
    public static let defaultPorts: [String: Port] = [
        "http": 80,
        "https": 443,
        "ws": 80,
        "wss": 443
    ]

    /// The default port for scheme associated with this URI if known
    public var defaultPort: Port? {
        return URI.defaultPorts[scheme]
    }
}

extension String {
    public var isSecure: Bool {
        return self == "https" || self == "wss"
    }
}
