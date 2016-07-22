//
//  SMTPGreetingTests.swift
//  Engine
//
//  Created by Logan Wright on 7/12/16.
//
//

import XCTest

import Core
import Engine
@testable import SMTP

class SMTPClientTests: XCTestCase {
    static let allTests = [
        ("testGreeting", testGreeting),
        ("testInitializing", testInitializing),
        ("testAuthorizeLogin", testAuthorizeLogin),
        ("testAuthorizeLoginBadUser", testAuthorizeLoginBadUser),
        ("testAuthorizeLoginBadPass", testAuthorizeLoginBadPass),
        ("testAuthorizePlain", testAuthorizePlain),
        ("testReplyLine", testReplyLine),
        ("testReplyLineFail", testReplyLineFail),
        ("testInitialize", testInitialize),
        ("testSendEmail", testSendEmail),
    ]

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
            XCTFail("Should throw bad password")
        } catch SMTPClientError.invalidPassword(code: _, reply: _) {
            return
        }
    }

    func testAuthorizePlain() throws {
        let client = try SMTPClient<SMTPTestStream>(host: "smtp.host.com", port: 25, securityLayer: .none)
        let credentials = SMTPCredentials(user: username, pass: password)
        let extensions = [try EHLOExtension("AUTH PLAIN")] // Only plain, LOGIN overrides
        try client.authorize(extensions: extensions, using: credentials)
    }

    func testReplyLine() throws {
        let client = try SMTPClient<SMTPTestStream>(host: "smtp.host.com", port: 25, securityLayer: .none)
        try client.transmit(line: "TEST LINE", expectingReplyCode: 42)
    }

    func testReplyLineFail() throws {
        let client = try SMTPClient<SMTPTestStream>(host: "smtp.host.com", port: 25, securityLayer: .none)
        do {
            try client.transmit(line: "TEST LINE", expectingReplyCode: 100)
            XCTFail("should throw error")
        } catch SMTPClientError.unexpectedReply {
            return
        }
    }

    func testInitialize() throws {
        let client = try SMTPClient<SMTPTestStream>(host: "smtp.host.com", port: 25, securityLayer: .none)
        try client.stream.send("220 smtp.mysite.io welcome\r\n".bytes, flushing: true)
        let creds = SMTPCredentials(user: username, pass: password)
        try client.initializeSession(using: creds)
    }

    func testSendEmail() throws {
        let client = try SMTPClient<SMTPTestStream>(host: "smtp.host.com", port: 25, securityLayer: .none)
        try client.stream.send("220 smtp.mysite.io welcome\r\n".bytes, flushing: true)
        let creds = SMTPCredentials(user: username, pass: password)

        let email = Email(from: "from@email.com",
                          to: "to1@email.com", "to2@email.com",
                          subject: "Email Subject",
                          body: "Hello Email")

        let attachment = EmailAttachment(filename: "dummy.data",
                                         contentType: "dummy/data",
                                         body: [1,2,3,4,5])
        email.attachments.append(attachment)
        try client.send(email, using: creds)
    }

    private func makeTestClient() throws -> SMTPClient<SMTPTestStream> {
        return try SMTPClient<SMTPTestStream>(host: "smtp.host.com",
                                              port: 25,
                                              securityLayer: .none)
    }
}
