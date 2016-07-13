extension HTTPBody {
    /**
        Creates an HTTPBody that will use the chunked
        transfer encoding to send data asynchronously.

        See the ChunkStream class for more information.
    */
    public init(_ chunker: (ChunkStream) throws -> Void) {
        self = .chunked(chunker)
    }
}
