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

    public var body: Bytes

    public init(from: EmailAddressRepresentable, to: EmailAddressRepresentable..., subject: String, message: String) {
        self.from = from.emailAddress
        self.to = to.map { $0.emailAddress }
        self.subject = subject
        self.body = message.bytes
    }
}
