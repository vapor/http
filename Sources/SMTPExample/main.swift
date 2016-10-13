import Foundation
import Transport

import SMTP

// Simple Email

func simpleEmail(from: EmailAddressRepresentable, to: EmailAddressRepresentable) throws -> Email {
    return Email(
        from: from,
        to: to,
        subject: "Vapor SMTP - Simple",
        body: "Hello from Vapor SMTP 👋"
    )
}

// Complex Email

enum Error: Swift.Error {
    case missingFile
}

func complexEmail(from: EmailAddressRepresentable, to: EmailAddressRepresentable) throws -> Email {
    // MARK: Templated Body
    let body = multicolorHTML(pairs: ["va": "powderblue", "p": "white", "or": "purple"])

    // MARK: Attachment files
    guard let testPDF = EmailAttachment(filename: "vapor-test-pdf.pdf", in: workDir) else {
        throw Error.missingFile
    }
    guard let testPNG = EmailAttachment(filename: "vapor-test-img.png", in: workDir) else {
        throw Error.missingFile
    }

    // MARK: Email
    let email = Email(
        from: from,
        to: to,
        subject: "Vapor SMTP - Attachments, HTML",
        body: body
    )
    email.attachments.append(testPDF)
    email.attachments.append(testPNG)
    return email
}

// MARK: Config

/*
     Set your username and password here
     
     SendGrid:
     
     Credentials MUST have 'MAIL' permission. UI/API not required
     https://app.sendgrid.com/settings/credentials
     
     GMail:
     
     Gmail Username & Password
     LIMIT: Personal accounts have limits of about 100 emails a day.
     Currently the user is required to change their settings for their Gmail account to "Allow for less secure apps".
     
     Example:

        SMTPCredentials(user: "noreply", pass: "*********")
*/
let credentials: SMTPCredentials! = nil
assert(credentials != nil, "set credentials")

/*
     A Valid sender's email address, for example:
     
        let from: EmailAddressRepresentable = EmailAddress(name: "Password Rest", address: "password.reset@myapp.com")
     
        or
        
        let from: EmailAddressRepresentable = "noreply@myapp.com"
*/
let from: EmailAddressRepresentable! = nil
assert(from != nil, "set from email, ex: ")

/*
     The target email address. For example:

         let to: EmailAddressRepresentable = EmailAddress(name: "Password Rest", address: "password.reset@myapp.com")

         or

         let to: EmailAddressRepresentable = "noreply@myapp.com"
*/
let to: EmailAddressRepresentable! = nil
assert(from != nil, "set from email")


/**
     The email that will be sent to the target address, also try
     
         let email = try simpleEmail(from: from, to: to)
*/
let email: Email = try complexEmail(from: from, to: to)

// MARK: Send

let client = try SMTPClient<TCPClientStream>.makeSendGridClient()
let (code, reply) = try client.send(email, using: credentials)
print("Successfully sent email: \(code) \(reply)")
