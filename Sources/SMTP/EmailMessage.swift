import Foundation
import struct Base.Bytes

public struct EmailContent {

}

public struct EmailBody {
    public enum BodyType {
        case html, plain
    }

    public let type: BodyType
    public let content: String

    public init(type: BodyType = .plain, _ content: String) {
        self.type = type
        self.content = content
    }
}

public protocol EmailBodyRepresentable {
    var emailBody: EmailBody { get }
}

extension String: EmailBodyRepresentable {
    public var emailBody: EmailBody {
        return EmailBody(self)
    }
}

extension EmailBody: EmailBodyRepresentable {
    public var emailBody: EmailBody {
        return self
    }
}

public struct EmailAttachment {
    public let filename: String
    public let contentType: String

    public let body: Bytes

    public init(filename: String, contentType: String, body: Bytes) {
        self.filename = filename
        self.contentType = contentType
        self.body = body
    }
}

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
public struct EmailMessage {
    public let from: EmailAddress
    public let to: [EmailAddress]

    // TODO:
    //    var cc: [EmailAddress] = [] // carbon copies, need to sort
    //    var bcc: [EmailAddress] = [] // carbon copies w/ names not included in from list

    public let id: String = NSUUID().uuidString.components(separatedBy: "-").joined(separator: "")
    // TODO:
    //    let inReplyTo: String? = nil // id this message is intended to reply to

    public let subject: String

    // TODO:
    //    var comments: [String] = [] // ?
    //    var keywords: [String] = [] // ?

    public let date: String = RFC1123.now()

    // TODO:
    //    var extendedFields: [String: String] = [:]

    public var body: EmailBody
    public var attachments: [EmailAttachment] = []


    public init(from: EmailAddressRepresentable, to: EmailAddressRepresentable..., subject: String, body: EmailBodyRepresentable) {
        self.from = from.emailAddress
        self.to = to.map { $0.emailAddress }
        self.subject = subject
        self.body = body.emailBody
    }
}
