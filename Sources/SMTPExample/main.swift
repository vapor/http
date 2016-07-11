import Foundation
import Engine
import SMTP

// Simple Email

func simpleEmail(from: EmailAddressRepresentable, to: EmailAddressRepresentable) throws -> EmailMessage {
    return EmailMessage(from: from,
                        to: to,
                        subject: "Vapor SMTP - Simple",
                        body: "Hello from Vapor SMTP 👋")
}

// Complex Email

enum Error: ErrorProtocol {
    case missingFile
}

func complexEmail(from: EmailAddressRepresentable, to: EmailAddressRepresentable) throws -> EmailMessage {
    // MARK: Templated Body
    let body = multicolorHTML(pairs: ["va": "paleblue", "p": "white", "or": "purple"])

    // MARK: Attachment files
    guard let testPDF = EmailAttachment(filename: "vapor-test-pdf.pdf", in: workDir) else {
        throw Error.missingFile
    }
    guard let testPNG = EmailAttachment(filename: "vapor-test-img.png", in: workDir) else {
        throw Error.missingFile
    }

    // MARK: Email
    let email = EmailMessage(from: from,
                             to: to,
                             subject: "Vapor SMTP - Attachments, HTML",
                             body: body)
    email.attachments.append(testPDF)
    email.attachments.append(testPNG)
    return email
}

// MARK: Send

/*
 Set your username and password here
 
 SendGrid:
 
 Credentials MUST have 'MAIL' permission. UI/API not required
 https://app.sendgrid.com/settings/credentials
 
 GMail:
 
 Gmail Username & Password
 LIMIT: Personal accounts have limits of about 100 emails a day.
 
 Example:

    SMTPCredentials(user: "noreply", pass: "*********")
 */
let credentials: SMTPCredentials! = nil

/*
 The sender's email address, for example:
 
    let from: EmailAddressRepresentable = EmailAddress(name: "Password Rest", address: "password.reset@myapp.com")
 */
let from: EmailAddressRepresentable! = nil

/*
 The target email address. For example:
 
    let to: EmailAddressRepresentable = "someUser@fancyemail.com"
 */
let to: EmailAddressRepresentable! = nil

/*
 The email that will be sent to the target address, also try
 
     let email = try simpleEmail(from: from, to: to)
 */
let email: EmailMessage = try complexEmail(from: from, to: to)

let client = try SMTPClient<TCPClientStream>.makeGMailClient()
let (code, reply) = try client.send(email, using: credentials)
print("Successfully sent email: \(code) \(reply)")
