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
        let mid = NSUUID.smtpMessageId
        XCTAssert(mid.hasPrefix("<") && mid.contains("@") && mid.hasSuffix(">"))
    }
}
