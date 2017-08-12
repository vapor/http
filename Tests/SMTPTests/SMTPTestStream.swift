import Bits
import Core
import Transport
@testable import SMTP

let username = "user"
let password = "****"
let baduser = "bad-user"
let badpass = "bad-pass"

let plainLogin = "\0\(username)\0\(password)".makeBytes().base64Encoded.makeString()

let greeting = "220 smtp.gmail.com at your service"
let ehloResponse = "250-smtp.sendgrid.net\r\n250-8BITMIME\r\n250-SIZE 31457280\r\n250-AUTH PLAIN LOGIN\r\n250 AUTH=PLAIN LOGIN"

private let SMTPReplies: [String: String] = [
    "AUTH LOGIN\r\n": "334 " + "Username:".makeBytes().base64Encoded.makeString(),
    username.makeBytes().base64Encoded.makeString() + "\r\n": "334 " + "Password:".makeBytes().base64Encoded.makeString(),
    password.makeBytes().base64Encoded.makeString() + "\r\n": "235 passed",
    baduser.makeBytes().base64Encoded.makeString() + "\r\n": "500 invalid username",
    badpass.makeBytes().base64Encoded.makeString() + "\r\n": "500 invalid password",
    "AUTH PLAIN " + plainLogin + "\r\n": "235 passed",
    "TEST LINE" + "\r\n": "042 ok",
    "EHLO localhost" + "\r\n": ehloResponse,
    "QUIT" + "\r\n": "221 ok, buh bye",
    "MAIL FROM: <from@email.com>" + "\r\n": "250 go on",
    "RCPT TO: <to1@email.com>" + "\r\n": "250 go on",
    "RCPT TO: <to2@email.com>" + "\r\n": "250 go on",
    "DATA" + "\r\n": "354 data ok",
    "\r\n.\r\n": "250 email done"
]

final class SMTPTestStream: Transport.ClientStream, Transport.Stream {
    var isClosed: Bool
    var writeBuffer: Bytes
    var readBuffer: Bytes

    let scheme: String
    let hostname: String
    let port: Port

    init(scheme: String, hostname: String, port: Port) {
        isClosed = false
        writeBuffer = []
        readBuffer = []

        self.scheme = scheme
        self.hostname = hostname
        self.port = port
    }

    func setTimeout(_ timeout: Double) throws {

    }

    func close() throws {
        if !isClosed {
            isClosed = true
        }
    }
    
    func write(max: Int, from buffer: Bytes) throws -> Int {
        isClosed = false
        writeBuffer += buffer
        
        
        if let response = SMTPReplies[writeBuffer.makeString()] {
            readBuffer = response.makeBytes()
            writeBuffer = []
        } else {
            // If reply not known, set to buffer
            readBuffer = writeBuffer
        }
        
        print(writeBuffer.makeString())
        print(readBuffer.makeString())
        
        return buffer.count
    }

    func read(max: Int, into buffer: inout Bytes) throws -> Int {
        if readBuffer.count == 0 {
            try close()
            readBuffer = []
            buffer = []
            return 0
        }

        if max >= readBuffer.count {
            try close()
            let data = readBuffer
            readBuffer = []
            buffer = data
            return data.count
        }

        let data = readBuffer[0..<max].array
        readBuffer.removeFirst(max)
        buffer = data
        return data.count
    }
    
    func connect() throws {
        
    }
}
