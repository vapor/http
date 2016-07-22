import Foundation
import struct Core.Bytes

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

    /**
        The date the email was created
    */
    public let date: Date = Date()

    /**
        The main body of the email. Currently supports
    */
    public var body: EmailBody

    /**
        Attachments to include with the email.
    */
    public var attachments: [EmailAttachmentRepresentable]

    /**
         For customized situations, extensible message fields can be included.
         Note that these fields WILL be transmitted to servers and should be considered carefully
         before implementing
     */
    public var extendedFields: [String: String] = [:]

    /**
        Email constructor w/ necessary components.
    */
    public init(from: EmailAddressRepresentable, to: EmailAddressRepresentable..., subject: String, body: EmailBodyRepresentable, attachments: [EmailAttachmentRepresentable] = []) {
        self.from = from.emailAddress
        self.to = to.map { $0.emailAddress }
        self.subject = subject
        self.body = body.emailBody
        self.attachments = attachments
    }
}
