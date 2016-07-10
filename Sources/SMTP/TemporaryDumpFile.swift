/*
 SMTP Makes use of multiple RFC specs

 ESMTP
 https://tools.ietf.org/html/rfc1869#section-4.3
 SMTP
 https://tools.ietf.org/html/rfc5321#section-4.5.3.2

 AUTH
 https://tools.ietf.org/html/rfc821#page-4
 GREAT UNOFFICIAL AUTH
 http://www.fehcom.de/qmail/smtpauth.html

 LEGACY - DO NOT SUPPORT
 https://tools.ietf.org/html/rfc821#page-4

 Timeouts
 https://tools.ietf.org/html/rfc5321#section-4.5.3.2
 */



import Base
import Foundation

// TODO: Base?
struct RFC1123 {
    static func now() -> String {
        return Date().rfc1123
    }

    static let shared = RFC1123()
    var formatter: DateFormatter

    init() {
        formatter = DateFormatter()
        formatter.locale = Locale(localeIdentifier: "en_US")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss 'GMT'"
    }
}

extension Date {
    public var rfc1123: String {
        return RFC1123.shared.formatter.string(from: self)
    }
}


//print(RFC1123.now())
//print("")

//import Engine
//
//struct Email {
//    let sender: String
//    let recipients: [String]
//}
//
import Engine
//let sssstream = try FoundationStream(host: "smtp.gmail.com", port: 587, securityLayer: .none)
//let cccconnection = try sssstream.connect()
//// 220 service ready greeting
////print(try cccconnection.receive(max: 5000).string)
///*
// 220 smtp.gmail.com ESMTP p39sm303264qtp.14 - gsmtp
// */
//try cccconnection.send("EHLO localhost \r\n")
//
///*
// https://tools.ietf.org/html/rfc5321#section-4.1.1.1
//
// 250-smtp.gmail.com at your service, [209.6.42.158]
// 250-SIZE 35882577
// 250-8BITMIME
// 250-AUTH LOGIN PLAIN XOAUTH2 PLAIN-CLIENTTOKEN OAUTHBEARER XOAUTH
// 250-ENHANCEDSTATUSCODES
// 250-PIPELINING
// 250-CHUNKING
// 250 SMTPUTF8
//
// FINAL LINE IS `250` w/ NO `-`
// */
//print(try cccconnection.receive(max: 5000).string)
//
//try cccconnection.send("AUTH LOGIN\r\n")
//print(try cccconnection.receive(max: 5000).string)
//try cccconnection.send("vapor.smtptest@gmail.com".bytes.base64String + "\r\n")
//print(try cccconnection.receive(max: 5000).string)
//try cccconnection.send("vapor.test".bytes.base64String + "\r\n")
//print(try cccconnection.receive(max: 5000).string)
//try cccconnection.send("MAIL FROM:<vapor.smtptest@gmail.com> BODY=8BITMIME\r\n")
//print(try cccconnection.receive(max: 5000).string)
//try cccconnection.send("RCPT TO:<logan@qutheory.io> \r\n")
//print(try cccconnection.receive(max: 5000).string)
//try cccconnection.send("DATA\r\n")
//print(try cccconnection.receive(max: 5000).string)
///*
// C: Date: Thu, 21 May 1998 05:33:22 -0700
// C: From: John Q. Public <JQP@bar.com>
// C: Subject:  The Next Meeting of the Board
// C: To: Jones@xyz.com
// */
//try cccconnection.send("Subject: SMTP Subject Test\r\n")
//try cccconnection.send("Hello from smtp")
//try cccconnection.send("\r\n.\r\n")
//print(try cccconnection.receive(max: 5000).string)
//try cccconnection.send("QUIT\r\n")
//print(try cccconnection.receive(max: 5000).string)
//print("SMTP")

import Engine

import Foundation

extension NSUUID {
    static var smtpMessageId: String {
        return NSUUID().uuidString.components(separatedBy: "-").joined(separator: "")
    }
}

//struct InternetMessage {
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
//    let to: String
//    let from: String
//    let cc: [String]?
//    let bcc: [String]?
//    let id: String
//    let replyToId: String?
//
//}

/*
 Field           Min number      Max number      Notes

 trace           0               unlimited       Block prepended - see
 3.6.7

 resent-date     0*              unlimited*      One per block, required
 if other resent fields
 present - see 3.6.6

 resent-from     0               unlimited*      One per block - see
 3.6.6

 resent-sender   0*              unlimited*      One per block, MUST
 occur with multi-address
 resent-from - see 3.6.6

 resent-to       0               unlimited*      One per block - see
 3.6.6

 resent-cc       0               unlimited*      One per block - see
 3.6.6

 resent-bcc      0               unlimited*      One per block - see
 3.6.6

 resent-msg-id   0               unlimited*      One per block - see
 3.6.6

 orig-date       1               1

 from            1               1               See sender and 3.6.2



 Resnick                     Standards Track                    [Page 19]

 RFC 2822                Internet Message Format               April 2001


 sender          0*              1               MUST occur with multi-
 address from - see 3.6.2

 reply-to        0               1

 to              0               1

 cc              0               1

 bcc             0               1

 message-id      0*              1               SHOULD be present - see
 3.6.4

 in-reply-to     0*              1               SHOULD occur in some
 replies - see 3.6.4

 references      0*              1               SHOULD occur in some
 replies - see 3.6.4

 subject         0               1

 comments        0               unlimited

 keywords        0               unlimited

 optional-field  0               unlimited
 */



/*
 There are two limits that this standard places on the number of
 characters in a line. Each line of characters MUST be no more than
 998 characters, and SHOULD be no more than 78 characters, excluding
 the CRLF.

 The 998 character limit is due to limitations in many implementations
 which send, receive, or store Internet Message Format messages that
 simply cannot handle more than 998 characters on a line. Receiving
 implementations would do well to handle an arbitrarily large number
 of characters in a line for robustness sake. However, there are so
 many implementations which (in compliance with the transport
 requirements of [RFC2821]) do not accept messages containing more
 than 1000 character including the CR and LF per line, it is important
 for implementations not to create such messages.

 The more conservative 78 character recommendation is to accommodate
 the many implementations of user interfaces that display these
 messages which may truncate, or disastrously wrap, the display of
 more than 78 characters per line, in spite of the fact that such
 implementations are non-conformant to the intent of this
 specification (and that of [RFC2821] if they actually cause
 information to be lost). Again, even though this limitation is put on
 messages, it is encumbant upon implementations which display messages





 Resnick                     Standards Track                     [Page 6]

 RFC 2822                Internet Message Format               April 2001


 to handle an arbitrarily large number of characters in a line
 (certainly at least up to the 998 character limit) for the sake of
 robustness.
 */

//DispatchQueue.global(attributes: .qosBackground).after(when: DispatchTime(30), execute: { })

// TODO: MUST TIMEOUT
/*

 // TODO: MUST TIMEOUT

 4.5.3.2.  Timeouts

 An SMTP client MUST provide a timeout mechanism.  It MUST use per-
 command timeouts rather than somehow trying to time the entire mail
 transaction.  Timeouts SHOULD be easily reconfigurable, preferably
 without recompiling the SMTP code.  To implement this, a timer is set
 for each SMTP command and for each buffer of the data transfer.  The
 latter means that the overall timeout is inherently proportional to
 the size of the message.

 Based on extensive experience with busy mail-relay hosts, the minimum
 per-command timeout values SHOULD be as follows:

 */

extension DispatchTime {

    static var fiveMinutes: DispatchTime {
        // TODO: Currently can only set distant future or now :( fix when foundation updates
        return DispatchTime.distantFuture
    }
}


final class TimeoutOperation {
    typealias Timeout = (TimeoutOperation) -> Void

    let label: String
    private var timeout: Timeout?

    init(label: String, duration: DispatchTime, timeout: Timeout, queue: DispatchQueue = DispatchQueue.global(attributes: .qosBackground)) {
        self.label = label
        self.timeout = timeout

        queue.after(when: duration) { [weak self] in
            guard let welf = self, let timeout = welf.timeout else {
                // cancelled -- ok
                return
            }
            timeout(welf)
        }
    }

    func cancel() {
        timeout = nil
    }
}

enum TimeoutError: ErrorProtocol {
    case timedOut
}

import Base
//
//func timingOut<T>(_ time: Double, operation: () throws -> T) throws -> T {
//    Promise<T>.async(timingOut: <#T##DispatchTime#>, <#T##handler: (Promise<T>) throws -> Void##(Promise<T>) throws -> Void#>)
////    DispatchQueue.global(attributes: .qosBackground)
//}


extension Promise {
    static func timeout(_ timingOut: DispatchTime, operation: () throws -> T) throws -> T {
        // TODO: async is locked, it needs to be something like `block` or `lockForAsync`
        return try Promise<T>.async(timingOut: timingOut) { promise in
            let value = try operation()
            promise.resolve(with: value)
        }
    }
}

/*
 https://tools.ietf.org/html/rfc1869#section-4.3

 4.3.  Successful response

 If the server SMTP implements and is able to perform the EHLO
 command, it will return code 250.  This indicates that both the
 server and client SMTP are in the initial state, that is, there is no
 transaction in progress and all state tables and buffers are cleared.

 Normally, this response will be a multiline reply. Each line of the
 response contains a keyword and, optionally, one or more parameters.
 The syntax for a positive response, using the ABNF notation of [2],
 is:

 ehlo-ok-rsp  ::=      "250"    domain [ SP greeting ] CR LF
 / (    "250-"   domain [ SP greeting ] CR LF
 *( "250-"      ehlo-line           CR LF )
 "250"    SP ehlo-line           CR LF   )

 ; the usual HELO chit-chat
 greeting     ::= 1*<any character other than CR or LF>

 ehlo-line    ::= ehlo-keyword *( SP ehlo-param )

 ehlo-keyword ::= (ALPHA / DIGIT) *(ALPHA / DIGIT / "-")

 ; syntax and values depend on ehlo-keyword
 ehlo-param   ::= 1*<any CHAR excluding SP and all
 control characters (US ASCII 0-31
 inclusive)>

 ALPHA        ::= <any one of the 52 alphabetic characters
 (A through Z in upper case, and,
 a through z in lower case)>
 DIGIT        ::= <any one of the 10 numeric characters
 (0 through 9)>

 CR           ::= <the carriage-return character
 (ASCII decimal code 13)>
 LF           ::= <the line-feed character
 (ASCII decimal code 10)>
 */
extension String {
    var int: Int? {
        return Int(self)
    }
}

extension Collection {
    public subscript(safe idx: Index) -> Iterator.Element? {
        guard startIndex <= idx else { return nil }
        // NOT >=, endIndex is "past the end"
        guard endIndex > idx else { return nil }
        return self[idx]
    }
}

enum SMTPClientError: ErrorProtocol {
    case initializationFailed(code: Int, greeting: String)
    case initializationFailed554(reason: String)
    case invalidMultilineReplyCode(expected: Int, got: Int)
    case invalidEhloHeader
}

extension String: ErrorProtocol {}
import Base

private let crlf: Bytes = [.carriageReturn, .newLine]

struct SMTPExtension {

}

struct EmailAddress {
    let name: String?
    let address: String

    init(name: String? = nil, address: String) {
        self.name = name
        self.address = address
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
struct EmailMessage {
    let from: EmailAddress
    let to: [EmailAddress]

    // TODO:
    //    var cc: [EmailAddress] = []
    //    var bcc: [EmailAddress] = []

    let id: String = NSUUID().uuidString.components(separatedBy: "-").joined(separator: "")
    // TODO:
    //    let inReplyTo: String? = nil

    let subject: String

    // TODO:
    //    var comments: [String] = []
    //    var keywords: [String] = []

    let date: String = RFC1123.now()

    // TODO:
    //    var extendedFields: [String: String] = [:]

    var body: Bytes

    init(from: EmailAddressRepresentable, to: EmailAddressRepresentable..., subject: String, message: String) {
        self.from = from.emailAddress
        self.to = to.map { $0.emailAddress }
        self.subject = subject
        self.body = message.bytes
    }
}

extension Sequence where Iterator.Element == EmailAddress {
    func smtpFormatted() -> String {
        return self.map { $0.smtpLongFormatted } .joined(separator: ", ")
    }
}

protocol EmailAddressRepresentable {
    var emailAddress: EmailAddress { get }
}

extension EmailAddress: EmailAddressRepresentable {
    var emailAddress: EmailAddress {
        return self
    }
}

extension String: EmailAddressRepresentable {
    var emailAddress: EmailAddress {
        return EmailAddress(name: nil, address: self)
    }
}

extension EmailAddress: StringLiteralConvertible {
    init(stringLiteral string: String) {
        self.init(name: nil, address: string)
    }

    init(extendedGraphemeClusterLiteral string: String){
        self.init(name: nil, address: string)
    }

    init(unicodeScalarLiteral string: String){
        self.init(name: nil, address: string)
    }
}

extension EmailAddress {
    var smtpLongFormatted: String {
        var formatted = ""

        if let name = self.name {
            formatted += name
            formatted += " "
        }
        formatted += "<\(address)>"
        return formatted
    }
}

internal struct SMTPHeader {
    internal let domain: String
    internal let greeting: String

    internal init(_ line: String) throws {
        let split = line
            .bytes
            .split(separator: .space, maxSplits: 1)
            .map { $0.string }
        guard split.count >= 1 else { throw "must at least have domain" }
        domain = split[0]
        greeting = split[safe: 1] ?? ""
    }
}

/*
 ehlo-line    ::= ehlo-keyword *( SP ehlo-param )
 */
struct EHLOExtension {
    let keyword: String
    let params: [String]

    init(_ line: String) throws {
        let args = line.components(separatedBy: " ")
        guard let keyword = args.first else { throw "missing keyword" }
        self.keyword = keyword
        self.params = args.dropFirst().array // rm keyword
    }
}

extension String {
    func equals(caseInsensitive: String) -> Bool {
        return lowercased() == caseInsensitive.lowercased()
    }
}

enum SMTPAuthMethod {
    case plain
    case login
    // TODO: Support additional auth methods
}

struct SMTPCredentials {
    let user: String
    let pass: String
}

extension Sequence where Iterator.Element == EHLOExtension {
    var authExtension: EHLOExtension? {
        return self.lazy.filter { $0.keyword.equals(caseInsensitive: "AUTH") } .first
    }
}


/*
 Specific sequences are:

 CONNECTION ESTABLISHMENT

 S: 220
 E: 554

 EHLO or HELO

 S: 250
 E: 504 (a conforming implementation could return this code only
 in fairly obscure cases), 550, 502 (permitted only with an old-
 style server that does not support EHLO)

 MAIL

 S: 250
 E: 552, 451, 452, 550, 553, 503, 455, 555

 RCPT

 S: 250, 251 (but see Section 3.4 for discussion of 251 and 551)
 E: 550, 551, 552, 553, 450, 451, 452, 503, 455, 555

 DATA

 I: 354 -> data -> S: 250

 E: 552, 554, 451, 452

 E: 450, 550 (rejections for policy reasons)

 E: 503, 554

 RSET

 S: 250

 VRFY

 S: 250, 251, 252
 E: 550, 551, 553, 502, 504

 EXPN

 S: 250, 252
 E: 550, 500, 502, 504

 HELP

 S: 211, 214
 E: 502, 504

 NOOP

 S: 250

 QUIT

 S: 221
 */


// MARK: Sending

