import Engine

let stream = try FoundationStream(host: "smtp.gmail.com", port: 465, securityLayer: .tls)
let connection = try stream.connect()
// 220 service ready greeting
print(try connection.receive(max: 5000).string)
/*
 220 smtp.gmail.com ESMTP p39sm303264qtp.14 - gsmtp
 */
try connection.send("EHLO localhost \r\n")

/*
 https://tools.ietf.org/html/rfc5321#section-4.1.1.1

 250-smtp.gmail.com at your service, [209.6.42.158]
 250-SIZE 35882577
 250-8BITMIME
 250-AUTH LOGIN PLAIN XOAUTH2 PLAIN-CLIENTTOKEN OAUTHBEARER XOAUTH
 250-ENHANCEDSTATUSCODES
 250-PIPELINING
 250-CHUNKING
 250 SMTPUTF8
 
 FINAL LINE IS `250` w/ NO `-`
 */
print(try connection.receive(max: 5000).string)

try connection.send("AUTH LOGIN\r\n")
print(try connection.receive(max: 5000).string)
try connection.send("vapor.smtptest@gmail.com".bytes.base64String + "\r\n")
print(try connection.receive(max: 5000).string)
try connection.send("vapor.test".bytes.base64String + "\r\n")
print(try connection.receive(max: 5000).string)
try connection.send("MAIL FROM:<vapor.smtptest@gmail.com> BODY=8BITMIME\r\n")
print(try connection.receive(max: 5000).string)
try connection.send("RCPT TO:<logan@qutheory.io> \r\n")
print(try connection.receive(max: 5000).string)
try connection.send("DATA\r\n")
print(try connection.receive(max: 5000).string)
/*
 C: Date: Thu, 21 May 1998 05:33:22 -0700
 C: From: John Q. Public <JQP@bar.com>
 C: Subject:  The Next Meeting of the Board
 C: To: Jones@xyz.com
 */
try connection.send("Subject: SMTP Subject Test\r\n")
try connection.send("Hello from smtp")
try connection.send("\r\n.\r\n")
print(try connection.receive(max: 5000).string)
try connection.send("QUIT\r\n")
print(try connection.receive(max: 5000).string)
print("SMTP")
