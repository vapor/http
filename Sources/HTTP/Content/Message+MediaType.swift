// MARK: Message

extension MediaType : CustomStringConvertible {
    /// :nodoc:
    public var description: String {
        return String(bytes: self.bytes, encoding: .utf8) ?? ""
    }
}
