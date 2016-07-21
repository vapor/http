extension WebSocket {
    public enum Error: Swift.Error {
        case invalidPingFormat
        case unexpectedFragmentFrame
    }
}
