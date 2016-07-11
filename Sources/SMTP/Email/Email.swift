import Foundation
import struct Base.Bytes

/*
 to /
 cc /
 bcc /
 message-id /
 in-reply-to /
 references /
 subject /
 comments /
 keywords /
 optional-field)
 */

/**
    An email message that can be sent via an SMTP Client
*/
public final class Email {

    /**
        The email address the email will be sent from
    */
    public let from: EmailAddress

    /**
        The email addresses that the email should be sent to
    */
    public let to: [EmailAddress]

    // TODO:
    //    var cc: [EmailAddress] = [] // carbon copies, need to sort
    //    var bcc: [EmailAddress] = [] // carbon copies w/ names not included in from list

    /**
        The automatically generated message id.
    */
    public let id: String = NSUUID.smtpMessageId
    // TODO:
    //    let inReplyTo: String? = nil // id this message is intended to reply to

    /**
        The subject being sent by the email.
    */
    public let subject: String

    // TODO:
    //    var comments: [String] = [] // ?
    //    var keywords: [String] = [] // ?

    #if os(Linux)
    /**
        The date the email was created
    */
    public let date: NSDate = NSDate()
    #else
    /**
        The date the email was created
    */
    public let date: Date = Date()
    #endif

    /**
        The main body of the email. Currently supports 
    */
    public var body: EmailBody
    public var attachments: [EmailAttachmentRepresentable]

    /**
         For customized situations, extensible message fields can be included.
         Note that these fields WILL be transmitted to servers and should be considered carefully
         before implementing
     */
    public var extendedFields: [String: String] = [:]

    public init(from: EmailAddressRepresentable, to: EmailAddressRepresentable..., subject: String, body: EmailBodyRepresentable, attachments: [EmailAttachmentRepresentable] = []) {
        self.from = from.emailAddress
        self.to = to.map { $0.emailAddress }
        self.subject = subject
        self.body = body.emailBody
        self.attachments = attachments
    }

    public func makeDataHeaders() -> [String: String] {
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
