public enum Body {
    case data(Bytes)
    case chunked((ChunkStream) throws -> Void)
}
