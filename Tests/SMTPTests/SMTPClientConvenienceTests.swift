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
        XCTAssert(gmail.host == "smtp.gmail.com")
        XCTAssert(gmail.port == 465)
        XCTAssert(gmail.securityLayer == .tls)
    }

    func testSendGrid() throws {
        let gmail = try SMTPClient<SMTPTestStream>.makeSendGridClient()
        XCTAssert(gmail.host == "smtp.sendgrid.net")
        XCTAssert(gmail.port == 465)
        XCTAssert(gmail.securityLayer == .tls)
    }
}
