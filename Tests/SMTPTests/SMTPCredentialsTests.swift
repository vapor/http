//
//  SMTPGreetingTests.swift
//  Engine
//
//  Created by Logan Wright on 7/12/16.
//
//

import XCTest
import SMTP

class SMTPCredentialsTests: XCTestCase {
    static let allTests = [
        ("testCredentials", testCredentials),
    ]

    func testCredentials() throws {
        let creds = SMTPCredentials(user: "some.user", pass: "blue carrot cartwheel rodent")
        XCTAssert(creds.user == "some.user")
        XCTAssert(creds.pass == "blue carrot cartwheel rodent")
    }
}
