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
            guard isLast else { throw "invalid username reply \(code) \(reply)" }
            guard code == 334 && reply.base64DecodedString.equals(caseInsensitive: "Username:") else { throw " invalid login reply \(code) \(reply)" }
            try transmit(line: credentials.user.bytes.base64String)
        }

        func handlePass() throws {
            let (code, reply, isLast) = try acceptReplyLine()
            guard isLast else { throw "invalid password reply \(code) \(reply)" }
            guard code == 334 && reply.base64DecodedString.equals(caseInsensitive: "Password:") else { throw " invalid login reply \(code) \(reply)" }
            try transmit(line: credentials.pass.bytes.base64String)
        }

        try transmit(line: "AUTH LOGIN")
        try handleUsername()
        try handlePass()

        let (code, reply, isLast) = try acceptReplyLine()
        guard isLast else { throw "unexpected authorization reply \(code) \(reply)" }
        guard code == 235 else { throw "authorization failed w/ \(code) \(reply)" }

        return // logged in successful
    }

    private func authorizePlain(_ credentials: SMTPCredentials) throws {
        let plainAuth = "\0\(credentials.user)\0\(credentials.pass)".bytes.base64String
        try transmit(line: "AUTH PLAIN \(plainAuth)")
        let (code, reply, isLast) = try acceptReplyLine()
        // 235 == authorization successful
        guard isLast && code == 235 else { throw "invalid reply \(code) \(reply)" }

        // authorization successful
        return
    }
}
