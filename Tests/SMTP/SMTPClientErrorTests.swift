//
//  SMTPGreetingTests.swift
//  Engine
//
//  Created by Logan Wright on 7/12/16.
//
//

import XCTest
import SMTP

class SMTPClientErrorTests: XCTestCase {
    static let allTests = [
        ("testReplies", testReplies),
        ("testCodes", testCodes),
    ]

    func testReplies() throws {
        let replies: [String] = ["test", "replies"]
        assert(.invalidMultilineReply(expected: 0, got: 0, replies: ["test reply"]), has: ["test reply"])
        assert(.invalidUsername(code: 0, reply: "test"), has: ["test"])
        assert(.invalidPassword(code: 0, reply: "pass"), has: ["pass"])
        assert(.authorizationFailed(code: 0, reply: "fail"), has: ["fail"])
        assert(.unexpectedReply(expected: 0, got: -1, replies: replies, initiator: ""), has: replies)
        assert(.unsupportedAuth(supportedByServer: ["a", "b", "c"], supportedBySMTP: ["d", "e", "f"]), has: [])
        assert(.initiationFailed(code: 0, replies: replies), has: replies)
        assert(.missingGreeting, has: [])
        assert(.invalidGreeting(code: 0, greeting: "not allowed"), has: ["not allowed"])
        assert(.quitFailed(code: 0, reply: "working"), has: ["working"])
    }

    func testCodes() throws {
        assert(.invalidMultilineReply(expected: 220, got: 500, replies: []), hasErrorCode: 500)
        assert(.invalidUsername(code: 504, reply: "unrecognized"), hasErrorCode: 504)
        assert(.invalidPassword(code: 504, reply: "invalid"), hasErrorCode: 504)
        assert(.authorizationFailed(code: 500, reply: "not authorized"), hasErrorCode: 500)
        assert(.unexpectedReply(expected: 400, got: 322, replies: [], initiator: ""), hasErrorCode: 322)
        assert(.unsupportedAuth(supportedByServer: ["a", "b", "c"], supportedBySMTP: ["d", "e", "f"]), hasErrorCode: -1)
        assert(.initiationFailed(code: 531, replies: []), hasErrorCode: 531)
        assert(.missingGreeting, hasErrorCode: -2)
        assert(.invalidGreeting(code: 500, greeting: "not allowed"), hasErrorCode: 500)
        assert(.quitFailed(code: 500, reply: "working"), hasErrorCode: 500)
    }

    private func assert(_ error: SMTPClientError, has replies: [String]) {
        XCTAssert(error.replies == replies)
    }

    private func assert(_ error: SMTPClientError, hasErrorCode code: Int) {
        XCTAssert(error.code == code)
    }
}
