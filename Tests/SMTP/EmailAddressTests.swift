//
//  SMTPGreetingTests.swift
//  Engine
//
//  Created by Logan Wright on 7/12/16.
//
//

import XCTest
import Core
@testable import SMTP

class EmailAddressTests: XCTestCase {
    static let allTests = [
        ("testLiteral", testLiteral),
        ("testRepresentable", testRepresentable),
    ]

    func testLiteral() {
        let a = EmailAddress(stringLiteral: "test@app.com")
        let b = EmailAddress(extendedGraphemeClusterLiteral: "test@app.com")
        let c = EmailAddress(unicodeScalarLiteral: "test@app.com")
        XCTAssert(a == b)
        XCTAssert(b == c)
        XCTAssert(a == c)

        XCTAssert(a == "test@app.com")
    }

    func testRepresentable() {
        let emailAddress = EmailAddress(name: "Name", address: "name@named.com")
        let rep: EmailAddressRepresentable = emailAddress
        XCTAssert(rep.emailAddress == emailAddress)

        let plain = EmailAddress(address: "joe@green.com")
        let plainRep = "joe@green.com"
        XCTAssert(plainRep.emailAddress == plain)
    }
}
