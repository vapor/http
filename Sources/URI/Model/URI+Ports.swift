extension URI {
    /**
        Default ports known to correspond with given schemes.
     
        Expand as possible
    */
    public static let defaultPorts = [
        "http": 80,
        "https": 443,
        "ws": 80,
        "wss": 443
    ]

    /**
        The default port for scheme associated with this URI if known
    */
    public var defaultPort: Int? {
        return URI.defaultPorts[scheme]
    }
}
