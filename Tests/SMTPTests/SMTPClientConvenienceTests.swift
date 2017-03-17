//
//  SMTPGreetingTests.swift
//  Engine
//
//  Created by Logan Wright on 7/12/16.
//
//

import XCTest
@testable import SMTP

class SMTPClientConvenienceTests: XCTestCase {
    static let allTests = [
        ("testGmail", testGmail),
        ("testSendGrid", testSendGrid),
    ]

    func testGmail() throws {
        let gmail = try SMTPClient<SMTPTestStream>.makeGmailClient()
        XCTAssertEqual(gmail.hostname, "smtp.gmail.com")
        XCTAssertEqual(gmail.port, 465)
        XCTAssertEqual(gmail.scheme, "smtps")
    }

    func testSendGrid() throws {
        let sendgrid = try SMTPClient<SMTPTestStream>.makeSendGridClient()
        XCTAssertEqual(sendgrid.hostname, "smtp.sendgrid.net")
        XCTAssertEqual(sendgrid.port, 465)
        XCTAssertEqual(sendgrid.scheme, "smtps")
    }
}
