extension Body {
    /**
        Creates an Body that will use the chunked
        transfer encoding to send data asynchronously.

        See the ChunkStream class for more information.
    */
    public init(_ chunker: @escaping (ChunkStream) throws -> Void) {
        self = .chunked(chunker)
    }
}
