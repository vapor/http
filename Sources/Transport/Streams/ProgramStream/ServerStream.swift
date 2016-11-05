public protocol ServerStream: ProgramStream, Watchable {
    func accept() throws -> Stream
}
