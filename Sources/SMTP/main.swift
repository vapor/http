import Engine

// MARK: Demo
//

let html = EmailBody(type: .html, "Hello <b style=\"color:red\">stylized html email</b>")
let client = try SMTPClient<FoundationStream>.makeSendGridClient()
let address = EmailAddress(name: "Vapor SMTP", address: "logan.william.wright@gmail.com")
let email = EmailMessage(from: address,
                         to: "logan@qutheory.io",
                         subject: "hehlo, confirming functional",
                         body: html)
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

