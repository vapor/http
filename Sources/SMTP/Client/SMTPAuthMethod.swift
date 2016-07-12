internal enum SMTPAuthMethod {
    case plain
    case login
    // TODO: Support additional auth methods
}

extension SMTPAuthMethod {
    static let all: [String] = ["PLAIN", "LOGIN"]
}
