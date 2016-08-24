//
//  SMTPGreetingTests.swift
//  Engine
//
//  Created by Logan Wright on 7/12/16.
//
//

import XCTest
@testable import SMTP

class SMTPExtensionsTests: XCTestCase {
    static let allTests = [
        ("testMissing", testMissing),
        ("testSingle", testSingle),
        ("testDouble", testDouble),
        ("testTriple", testTriple),
        ("testAuthExtension", testAuthExtension),
    ]

    func testMissing() {
        do {
            _ = try EHLOExtension("")
            XCTFail("Empty should throw")
        } catch { return }
    }

    func testSingle() throws {
        let mime = try EHLOExtension("8BITMIME")
        XCTAssert(mime.keyword == "8BITMIME")
        XCTAssert(mime.params == [])
    }

    func testDouble() throws {
        let mime = try EHLOExtension("SIZE 31457280")
        XCTAssert(mime.keyword == "SIZE")
        XCTAssert(mime.params == ["31457280"])
    }

    func testTriple() throws {
        let mime = try EHLOExtension("AUTH PLAIN LOGIN")
        XCTAssert(mime.keyword == "AUTH")
        XCTAssert(mime.params == ["PLAIN", "LOGIN"])
    }

    func testAuthExtension() throws {
        let extensions = try ["8BITMIME", "PIPELINING", "SIZE 31457280", "AUTH PLAIN LOGIN", "AUTH=PLAIN LOGIN"]
            .map(EHLOExtension.init)

        let auth = extensions.authExtension
        XCTAssert(auth?.keyword == "AUTH")
        let params = auth?.params ?? []
        XCTAssert(params == ["PLAIN", "LOGIN"])
    }
}
