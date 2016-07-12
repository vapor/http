/*
     ***** [WARNING] *****
     Sensitive code below, carefully consult all relating RFC specs,
     these two are a good place to start

     https://tools.ietf.org/html/rfc2554
     http://www.fehcom.de/qmail/smtpauth.html
*/
extension SMTPClient {
    internal func authorize(method: SMTPAuthMethod, using credentials: SMTPCredentials) throws {
        switch method {
        case .login:
            try authorizeLogin(credentials)
        case .plain:
            try authorizePlain(credentials)
        }
    }

    private func authorizeLogin(_ credentials: SMTPCredentials) throws {
        func handleUsername() throws {
            let (code, reply, isLast) = try acceptReplyLine()
            guard
                isLast
                && code == 334
                && reply.base64DecodedString.equals(caseInsensitive: "Username:")
                // This means the command BEFORE failed
                else { throw SMTPClientError.authorizationFailed(code: code, reply: reply) }
            try transmit(line: credentials.user.bytes.base64String)
        }

        func handlePass() throws {
            let (code, reply, isLast) = try acceptReplyLine()
            guard
                isLast
                && code == 334
                && reply.base64DecodedString.equals(caseInsensitive: "Password:")
                // If Username fails, we don't get password
                else { throw SMTPClientError.invalidUsername(code: code, reply: reply) }
            try transmit(line: credentials.pass.bytes.base64String)
        }

        try transmit(line: "AUTH LOGIN")
        try handleUsername()
        try handlePass()

        let (code, reply, isLast) = try acceptReplyLine()
        guard
            isLast
            && code == 235
            else { throw SMTPClientError.invalidPassword(code: code, reply: reply) }

        return // logged in successful
    }

    private func authorizePlain(_ credentials: SMTPCredentials) throws {
        let plainAuth = "\0\(credentials.user)\0\(credentials.pass)".bytes.base64String
        try transmit(line: "AUTH PLAIN \(plainAuth)")
        let (code, reply, isLast) = try acceptReplyLine()
        // 235 == authorization successful
        guard
            isLast
            && code == 235
            else { throw SMTPClientError.authorizationFailed(code: code, reply: reply) }

        // authorization successful
        return
    }
}
