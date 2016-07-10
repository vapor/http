import Foundation
import Engine

let workDir: String?
#if Xcode
let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
workDir = "/\(parent)/../.."
#else
workDir = nil
#endif


let url = NSURL.fileURL(withPath: workDir! + "/vapor-test-img.png")
//let url = URL(string: workDir! + "/vapor-test-img")!
print("URL: \(url)")
let testData = NSData(contentsOf: url)!
var bytes = Bytes(repeating: 0, count: testData.length)
testData.getBytes(&bytes, length: testData.length)

let attach = EmailAttachment(filename: "vapor-test-img", type: "png", body: bytes)
//print("Got data: \(testData)")
print("")


// MARK: Demo
//

var _html = ""
_html += "<!DOCTYPE html>"
_html += "<html>"
_html += "<body style=\"background-color:black;\">"

_html += "<h1 align=\"center\"><b style=\"color:red\">am</b><b style=\"color:white\">eri</b><b style=\"color:blue\">ca</b></h1>"

_html += "</body>"
_html += "</html>"

let html = EmailBody(type: .html, _html)//"Hello <b style=\"color:red\">am</b><b style=\"color:white\">eri</b><b style=\"color:blue\">ca</b>")
let client = try SMTPClient<FoundationStream>.makeSendGridClient()
let address = EmailAddress(name: "Vapor SMTP", address: "logan.william.wright@gmail.com")
var email = EmailMessage(from: address,
                         to: "logan@qutheory.io",
                         subject: "smtp-formatted-html",
                         body: html)
email.attachments.append(attach)
let auth = SMTPCredentials(user: "smtp.test", pass: "smtp.pass1")
let (code, reply) = try client.send(email, using: auth)
print("\(code) \(reply)") // smtp.pass1
print("")


//let credentials = SMTPCredentials(user: "vapor.smtptest@gmail.com", pass: "smtp.pass1")
//
//let client = try SMTPClient<FoundationStream>.makeGMailClient()
//let address = EmailAddress(name: "Vapor SMTP", address: "logan.william.wright@gmail.com")
////let emails: [EmailMessage] = (1...10).map { i in
////    return EmailMessage(from: address,
////                             to: "logan@qutheory.io",
////                             subject: "[multiple - \(i)]",
////                             message: "😶")
////}
////let (code, reply) = try client.send(emails: emails, using: credentials)
//let email = EmailMessage(from: address,
//                         to: "logan@qutheory.io",
//                         subject: "the past is real",
//                         message: "😶")
//let (code, reply) = try client.send(email, using: credentials)
//print("\(code) \(reply)")
//print("")






//
//let gmailAuth = SMTPAuth(user: "vapor.smtptest@gmail.com", pass: "smtp.pass1")

//let gmailAuth = SMTPAuth(user: "vapor.smtptest@gmail.com", pass: "****")
//
//let email = EmailMessage(from: "noreply@mycoolproject.io",
//                         to: "joe@gmail.com", "jan@yahoo.com",
//                         subject: "Vapor SMTP",
//                         message: "Hello Email 👋")
//let client = try SMTPClient<FoundationStream>.makeGMailClient()
//try client.send(email, using: gmailAuth)

//print("\(code) \(reply)")


print("")

