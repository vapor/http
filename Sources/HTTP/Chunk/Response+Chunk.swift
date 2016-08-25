extension Response {
    /**
        Send chunked data with the
        `Transfer-Encoding: Chunked` header.

        Chunked uses the Transfer-Encoding HTTP header in
        place of the Content-Length header.

        https://en.wikipedia.org/wiki/Chunked_transfer_encoding
    */
    public convenience init(status: Status = .ok, headers: [HeaderKey: String] = [:], chunked closure: @escaping ((ChunkStream) throws -> Void)) {
        self.init(status: status, headers: headers, body: .chunked(closure))
    }
}
