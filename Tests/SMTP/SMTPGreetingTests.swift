//
//  SMTPGreetingTests.swift
//  Engine
//
//  Created by Logan Wright on 7/12/16.
//
//

import XCTest
@testable import SMTP

class SMTPGreetingTests: XCTestCase {
    static let allTests = [
        ("testGmailGreeting", testGmailGreeting),
        ("testSendGridGreeting", testSendGridGreeting),
        ("testBadDomain", testBadDomain),
    ]

    func testGmailGreeting() throws {
        let gmailGreeting = "smtp.gmail.com at your service, [199.6.34.128]"
        let greeting = try SMTPGreeting(gmailGreeting)
        XCTAssert(greeting.domain == "smtp.gmail.com")
        XCTAssert(greeting.greeting == "at your service, [199.6.34.128]")
    }

    func testSendGridGreeting() throws {
        let sendGridGreeting = "smtp.sendgrid.net"
        let greeting = try SMTPGreeting(sendGridGreeting)
        XCTAssert(greeting.domain == "smtp.sendgrid.net")
        XCTAssert(greeting.greeting == "")
    }

    func testBadDomain() {
        let greeting = ""
        do {
            _ = try SMTPGreeting(greeting)
            XCTFail("Bad greeting")
        } catch { return }
    }
}
