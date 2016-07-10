import Foundation

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
    private func transmitDATA(for email: EmailMessage) throws {
        // open data
        try transmit(line: "DATA", expectingReplyCode: 354)

        // Data Headers
        // TODO: Might not need date, add way to customize email headers!
        // TODO: Don't forget header extensibility
        try transmit(line: "Date: " + email.date)
        try transmit(line: "Message-id: " + email.id)
        try transmit(line: "From: " + email.from.smtpLongFormatted)
        try transmit(line: "To:" + email.to.smtpLongFormatted)
        try transmit(line: "Subject: " + email.subject)
        try transmit(line: "MIME-Version: 1.0 (Vapor SMTP)")
        try transmit(line: "Content-type: multipart/mixed; boundary=\"vapor-smtp-boundary\"")
        try transmit(line: "") // empty line to start body
        // Data Headers End

        // TODO: Lines should always terminate, right? Is this something else?
//        try transmit(line: "preamble, ignored by parsers, handy info for non-mime compliant reader", terminating: false)
        try transmit(line: "--vapor-smtp-boundary")
        try transmit(email.body)
//        try stream.send("Content-Type: text/html; charset=utf8\r\n\r\n")
//        try stream.send("HTML? <b>im bold</b>\r\n")
//        try transmit(line: "This is implicitly typed plain ASCII text. It does NOT end with a linebreak. ", terminating: false)
//        try transmit(line: "--simple boundary\r\n", terminating: false)
//        try transmit(line: "Content-type: text/plain; charset=us-ascii\r\n\r\n", terminating: false)
//        try transmit(line: "This IS explicitly typed plain ascii text. it DOES end w/ a line break", terminating: true)
        try transmit(line: "--vapor-smtp-boundary--")
        try transmit(line: "") // empty line

        // Send Message
//        try stream.send(email.body, flushing: true)
        // Message Done

        // TODO: Send Attachments? Migh tbe below operator

        // close data w/ data terminator -- don't need additional terminating `\r\n`
        try transmit(line: "\r\n.\r\n", terminating: false, expectingReplyCode: 250)
    }

    private func transmit(_ body: EmailBody) throws {
//        try transmit(line: "--vapor-smtp-boundary\r\n", terminating: false)

        let contentType: String
        switch body.type {
        case .html:
            contentType = "text/html"
        case .plain:
            contentType = "text/plain"
        }
        try transmit(line: "Content-Type: \(contentType); charset=utf8")
        try transmit(line: "")  // empty line

        try transmit(line: body.content)
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
