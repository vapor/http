public struct SMTPCredentials {
    public let user: String
    public let pass: String

    public init(user: String, pass: String) {
        self.user = user
        self.pass = pass
    }
}
