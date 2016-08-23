//
//  SMTPGreetingTests.swift
//  Engine
//
//  Created by Logan Wright on 7/12/16.
//
//

import XCTest

@testable import SMTP

class EmailBodyTests: XCTestCase {
    static let allTests = [
        ("testLiteral", testLiteral),
        ("testHTML", testHTML),
    ]

    func testLiteral() {
        let a = EmailBody(content: "Hello SMTP!")
        let b = "Hello SMTP!"
        let c = EmailBody(type: .plain, content: "Hello SMTP!")
        XCTAssert(a == b.emailBody)
        XCTAssert(b.emailBody == c)
        XCTAssert(a == c)
        XCTAssert(a.emailBody == b.emailBody)
    }

    func testHTML() {
        let html = EmailBody(type: .html, content: "<h1>Welcome</h1>")
        XCTAssert(html.type == .html)
        XCTAssert(html.content == "<h1>Welcome</h1>")
    }
}
