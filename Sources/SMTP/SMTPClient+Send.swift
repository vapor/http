extension SMTPClient {
    /*
     Send an email to connection using specified credentials
     */
    @discardableResult
    public func send(_ email: EmailMessage, using auth: SMTPCredentials) throws -> (code: Int, greeting: String) {
        return try send([email], using: auth)
    }

    /**
     Can send multiple emails, some limits. for example, SendGrid limits to 100 messages per connection.
     Because we can't determine the amount of permitted emails on a single connection, it is the user's
     responsibility to determine and enforce the limits of the system they are using.
     */
    @discardableResult
    public func send(_ emails: [EmailMessage], using creds: SMTPCredentials) throws -> (code: Int, greeting: String) {
        return try negotiateSession(using: creds) { client in
            try emails.forEach(transmit)
        }
    }

    /**
     Once a session has been initialized, emails can be processed
     */
    private func transmit(_ email: EmailMessage) throws {
        try transmit(line: "MAIL FROM: <\(email.from.address)>", expectingReplyCode: 250)
        for to in email.to {
            try transmit(line: "RCPT TO: <\(to.address)>", expectingReplyCode: 250)
        }

        try transmitDATA(for: email)
    }

    private func transmitDATA(for email: EmailMessage) throws {
        // open data
        try transmit(line: "DATA", expectingReplyCode: 354)

        // Data Headers
        try transmit(line: "Date: " + email.date)
        try transmit(line: "Message-id: " + email.id)
        try transmit(line: "From: " + email.from.smtpLongFormatted)
        try transmit(line: "To:" + email.to.smtpLongFormatted)
        try transmit(line: "Subject: " + email.subject)
        try transmit(line: "") // empty line to start body
        // Data Headers End

        // Send Message
        try stream.send(email.body, flushing: true)
        // Message Done

        // TODO: Send Attachments? Migh tbe below operator

        // close data w/ data terminator -- don't need additional terminating `\r\n`
        try transmit(line: "\r\n.\r\n", terminating: false, expectingReplyCode: 250)
    }
}

extension EmailAddress {
    private var smtpLongFormatted: String {
        var formatted = ""

        if let name = self.name {
            formatted += name
            formatted += " "
        }
        formatted += "<\(address)>"
        return formatted
    }
}

extension Sequence where Iterator.Element == EmailAddress {
    private var smtpLongFormatted: String {
        return self.map { $0.smtpLongFormatted } .joined(separator: ", ")
    }
}
