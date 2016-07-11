import Foundation
import struct Base.Bytes

//    /*
//     to /
//     cc /
//     bcc /
//     message-id /
//     in-reply-to /
//     references /
//     subject /
//     comments /
//     keywords /
//     optional-field)
//     */
public final class Email {

    public let from: EmailAddress
    public let to: [EmailAddress]

    // TODO:
    //    var cc: [EmailAddress] = [] // carbon copies, need to sort
    //    var bcc: [EmailAddress] = [] // carbon copies w/ names not included in from list

    public let id: String = NSUUID.smtpMessageId
    // TODO:
    //    let inReplyTo: String? = nil // id this message is intended to reply to

    public let subject: String

    // TODO:
    //    var comments: [String] = [] // ?
    //    var keywords: [String] = [] // ?

    #if os(Linux)
    public let date: NSDate = NSDate()
    #else
    public let date: Date = Date()
    #endif

    // TODO:
    var extendedFields: [String: String] = [:]

    public var body: EmailBody
    public var attachments: [EmailAttachmentRepresentable]

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
