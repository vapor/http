//
//  SMTPGreetingTests.swift
//  Engine
//
//  Created by Logan Wright on 7/12/16.
//
//

import XCTest
import Foundation
@testable import SMTP

class SMTPUUIDTests: XCTestCase {
    static let allTests = [
        ("testSMTPUUID", testSMTPUUID),
    ]

    func testSMTPUUID() {
        XCTAssert(NSUUID.smtpMessageId.components(separatedBy: "-").count == 1)
    }
}
