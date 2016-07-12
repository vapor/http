extension SMTPClient {
    /**
        Send an email to connection using specified credentials
    */
    @discardableResult
    public func send(_ email: Email, using auth: SMTPCredentials) throws -> (code: Int, greeting: String) {
        return try send([email], using: auth)
    }

    /**
         Can send multiple emails, some limits. for example, SendGrid limits to 100 messages per connection.
         Because we can't determine the amount of permitted emails on a single connection, it is the user's
         responsibility to determine and enforce the limits of the system they are using.
    */
    @discardableResult
    public func send(_ emails: [Email], using creds: SMTPCredentials) throws -> (code: Int, greeting: String) {
        return try negotiateSession(using: creds) { client in
            try emails.forEach(transmit)
        }
    }

    /**
        Once a session has been initialized, emails can be processed
    */
    private func transmit(_ email: Email) throws {
        try transmit(line: "MAIL FROM: <\(email.from.address)>", expectingReplyCode: 250)
        for to in email.to {
            try transmit(line: "RCPT TO: <\(to.address)>", expectingReplyCode: 250)
        }

        try transmitDATA(for: email)
    }

    /*
         From: Nathaniel Borenstein <nsb@bellcore.com>
         To:  Ned Freed <ned@innosoft.com>
         Subject: Sample message
         MIME-Version: 1.0
         Content-type: multipart/mixed; boundary="simple
         boundary"

         This is the preamble.  It is to be ignored, though it
         is a handy place for mail composers to include an
         explanatory note to non-MIME compliant readers.
         --simple boundary

         This is implicitly typed plain ASCII text.
         It does NOT end with a linebreak.
         --simple boundary
         Content-type: text/plain; charset=us-ascii

         This is explicitly typed plain ASCII text.
         It DOES end with a linebreak.

         --simple boundary--
         This is the epilogue.  It is also to be ignored.
    */
    private func transmitDATA(for email: Email) throws {
        // open data
        try transmit(line: "DATA", expectingReplyCode: 354)

        // transmit headers
        for (key, val) in email.makeDataHeaders() {
            try transmit(line: "\(key): \(val)")
        }
        let boundary = "vapor-smtp-multipart-boundary"
        try transmit(line: "Content-type: multipart/mixed; boundary=\"\(boundary)\"")
        try transmit(line: "") // empty line to start body
        // Data Headers End

        try transmit(email.body, withBoundary: boundary)
        try email.attachments.map { $0.emailAttachment } .forEach { attachment in
            try transmit(attachment, withBoundary: boundary)
        }

        // terminate multipart
        try transmit(line: "--\(boundary)--")
        try transmit(line: "") // empty line
        // close parts

        // close data w/ data terminator -- don't need additional terminating `\r\n`
        try transmit(line: "\r\n.\r\n", terminating: false, expectingReplyCode: 250)
    }

    private func transmit(_ body: EmailBody, withBoundary boundary: String) throws {
        try transmit(line: "--\(boundary)")

        let contentType: String
        switch body.type {
        case .html:
            contentType = "text/html"
        case .plain:
            contentType = "text/plain"
        }
        try transmit(line: "Content-Type: \(contentType); charset=utf8")
        try transmit(line: "") // empty line

        try stream.send(body.content)
        try transmit(line: "") // empty line
    }

    private func transmit(_ attachment: EmailAttachment, withBoundary boundary: String) throws {
        try transmit(line: "--\(boundary)")
        try transmit(line: "Content-Disposition: attachment; filename=\(attachment.filename)\r\n", terminating: false)
        try transmit(line: "Content-Type: \(attachment.contentType); name=\(attachment.filename)\r\n", terminating: false)
        try transmit(line: "Content-Transfer-Encoding: base64")
        try transmit(line: "")
        /*
             Note that we are converting ALL attachments to base64. This is supported by all SMTP systems
             others do support 'BINARYMIME', but none in my tests seemed to, so in the interest
             of brevity and consistency, we're sacraficing a very small amount of performance
        */
        try stream.send(attachment.body.base64Data)
        try transmit(line: "") // empty line
    }
}

extension Email {
    private func makeDataHeaders() -> [String: String] {
        var dataHeaders: [String : String] = [:]
        dataHeaders["Date"] = date.smtpFormatted
        dataHeaders["Message-Id"] = id
        dataHeaders["From"] = from.smtpLongFormatted
        dataHeaders["To"] = to.smtpLongFormatted
        dataHeaders["Subject"] = subject
        dataHeaders["MIME-Version"] = "1.0 (Vapor SMTP)"
        for (key, val) in extendedFields {
            dataHeaders[key] = val
        }
        return dataHeaders
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
