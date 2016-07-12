//
//  SMTPGreetingTests.swift
//  Engine
//
//  Created by Logan Wright on 7/12/16.
//
//

import XCTest
@testable import SMTP

class SMTPUUIDTests: XCTestCase {
    func testSMTPDate() {
        XCTAssert(NSUUID.smtpMessageId.components(separatedBy: "-").count == 1)
    }
}
