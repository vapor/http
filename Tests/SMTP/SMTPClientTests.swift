//
//  SMTPGreetingTests.swift
//  Engine
//
//  Created by Logan Wright on 7/12/16.
//
//

import XCTest
import Base
import Engine
@testable import SMTP

let username = "user"
let password = "****"
let baduser = "bad-user"
let badpass = "bad-pass"

let plainLogin = "\0\(username)\0\(password)".bytes.base64String

let replies: [String: String] = [
    "AUTH LOGIN\r\n": "334 " + "Username:".bytes.base64String,
    username.bytes.base64String + "\r\n": "334 " + "Password:".bytes.base64String,
    password.bytes.base64String + "\r\n": "235 passed",
    baduser.bytes.base64String + "\r\n": "500 invalid username",
    badpass.bytes.base64String + "\r\n": "500 invalid password",
    "AUTH PLAIN " + plainLogin + "\r\n": "235 passed"
]

final class SMTPTestStream: Engine.ClientStream, Engine.Stream {
    var closed: Bool
    var buffer: Bytes

    let host: String
    let port: Int
    let securityLayer: SecurityLayer

    init(host: String, port: Int, securityLayer: SecurityLayer) {
        closed = false
        buffer = []

        self.host = host
        self.port = port
        self.securityLayer = securityLayer
    }

    func setTimeout(_ timeout: Double) throws {

    }

    func close() throws {
        if !closed {
            closed = true
        }
    }

    func send(_ bytes: Bytes) throws {
        closed = false
        print("Send: \(bytes.string)")
        if let response = replies[bytes.string] {
            buffer += response.bytes
        } else {
            // If reply not known, set to buffer
            buffer += bytes
        }
    }

    func flush() throws {

    }

    func receive(max: Int) throws -> Bytes {
        if buffer.count == 0 {
            try close()
            return []
        }

        if max >= buffer.count {
            try close()
            let data = buffer
            buffer = []
            return data
        }

        let data = buffer[0..<max]
        buffer.removeFirst(max)

        return Bytes(data)
    }

    func connect() throws -> Engine.Stream {
        return self
    }
}


let greeting: String = "220 smtp.gmail.com at your service"
let ehloResponse: String = "250-smtp.sendgrid.net\r\n250-8BITMIME\r\n250-SIZE 31457280\r\n250-AUTH PLAIN LOGIN\r\n250 AUTH=PLAIN LOGIN"
//"250 ["smtp.sendgrid.net", "8BITMIME", "PIPELINING", "SIZE 31457280", "AUTH PLAIN LOGIN", "AUTH=PLAIN LOGIN"]
let serverSuccessResponses: [String] = [
]

func makeTestClient() throws -> SMTPClient<TestStream> {
    return try SMTPClient<TestStream>(host: "smtp.host.com",
                                      port: 25,
                                      securityLayer: .none)
}

class SMTPClientTests: XCTestCase {
    func testGreeting() throws {
        let client = try makeTestClient()
        // load buffer
        try client.stream.send(greeting.bytes, flushing: true)
        let (code, reply) = try client.acceptGreeting()
        XCTAssert(code == 220)
        XCTAssert(reply.domain == "smtp.gmail.com")
        XCTAssert(reply.greeting == "at your service")

    }

    func testInitializing()throws  {
        let client = try makeTestClient()
        // load buffer
        try client.stream.send(ehloResponse.bytes, flushing: true)
        let (code, reply) = try client.acceptReply()
        XCTAssert(code == 250)
        XCTAssert(reply == ["smtp.sendgrid.net", "8BITMIME", "SIZE 31457280", "AUTH PLAIN LOGIN", "AUTH=PLAIN LOGIN"])
    }

    func testAuthorizeLogin() throws {
        let client = try SMTPClient<SMTPTestStream>(host: "smtp.host.com", port: 25, securityLayer: .none)
        let credentials = SMTPCredentials(user: username, pass: password)
        let extensions = [try EHLOExtension("AUTH LOGIN PLAIN")]
        try client.authorize(extensions: extensions, using: credentials)
    }

    func testAuthorizeLoginBadUser() throws {
        let client = try SMTPClient<SMTPTestStream>(host: "smtp.host.com", port: 25, securityLayer: .none)
        let credentials = SMTPCredentials(user: baduser, pass: password)
        let extensions = [try EHLOExtension("AUTH LOGIN PLAIN")]
        do {
            try client.authorize(extensions: extensions, using: credentials)
            XCTFail("Should throw bad user")
        } catch SMTPClientError.invalidUsername(code: _, reply: _) {
            return
        }
    }

    func testAuthorizeLoginBadPass() throws {
        let client = try SMTPClient<SMTPTestStream>(host: "smtp.host.com", port: 25, securityLayer: .none)
        let credentials = SMTPCredentials(user: username, pass: badpass)
        let extensions = [try EHLOExtension("AUTH LOGIN PLAIN")]
        do {
            try client.authorize(extensions: extensions, using: credentials)
            XCTFail("Should throw bad user")
        } catch SMTPClientError.invalidUsername(code: _, reply: _) {
            return
        }
    }

    func testAuthorizePlain() throws {
        let client = try SMTPClient<SMTPTestStream>(host: "smtp.host.com", port: 25, securityLayer: .none)
        let credentials = SMTPCredentials(user: username, pass: password)
        let extensions = [try EHLOExtension("AUTH PLAIN")] // Only plain, LOGIN overrides
        try client.authorize(extensions: extensions, using: credentials)
    }

    func testSMTPDate() {
        let date = NSDate(timeIntervalSince1970: 0)
        let smtpFormatted = date.smtpFormatted
        XCTAssert(smtpFormatted.hasPrefix("Wed, 31 Dec 1969 "))
        let suffix = smtpFormatted.components(separatedBy: "Wed, 31 Dec 1969 ").last ?? ""
        let timeComps = suffix.components(separatedBy: " ")
        XCTAssert(timeComps.count == 2)

        let timeOfDay = timeComps.first ?? ""
        let hoursMinutesSecond = timeOfDay.components(separatedBy: ":")
        XCTAssert(hoursMinutesSecond.count == 3)
        hoursMinutesSecond.forEach { comp in
            // ie: 01, not just 1
            XCTAssert(comp.characters.count == 2)
        }

        let timeZone = timeComps.last ?? ""
        XCTAssert(timeZone != "")
        XCTAssert(timeZone != timeOfDay)
    }
}


final class TestStream: Engine.ClientStream, Engine.Stream {
    var closed: Bool
    var buffer: Bytes

    let host: String
    let port: Int
    let securityLayer: SecurityLayer

    init(host: String, port: Int, securityLayer: SecurityLayer) {
        closed = false
        buffer = []

        self.host = host
        self.port = port
        self.securityLayer = securityLayer
    }

    func setTimeout(_ timeout: Double) throws {

    }

    func close() throws {
        if !closed {
            closed = true
        }
    }

    func send(_ bytes: Bytes) throws {
        print("buffered \(bytes.string)")
        closed = false
        buffer += bytes
    }

    func flush() throws {

    }

    func receive(max: Int) throws -> Bytes {
        if buffer.count == 0 {
            try close()
            return []
        }

        if max >= buffer.count {
            try close()
            let data = buffer
            buffer = []
            return data
        }

        let data = buffer[0..<max]
        buffer.removeFirst(max)
        
        return Bytes(data)
    }

    func connect() throws -> Engine.Stream {
        return self
    }
}
