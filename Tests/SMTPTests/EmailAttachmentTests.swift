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

class EmailAttachmentTests: XCTestCase {
    static let allTests = [
        ("testAttachment", testAttachment),
    ]

    func testAttachment() {
        let attachment = EmailAttachment(filename: "test.png",
                                         contentType: "image/png",
                                         body: [1,2,3,4,5])
        XCTAssert(attachment.filename == "test.png")
        XCTAssert(attachment.contentType == "image/png")
        XCTAssert(attachment.body == [1,2,3,4,5])

        let representable: EmailAttachmentRepresentable = attachment
        XCTAssert(representable.emailAttachment.filename == attachment.filename)
        XCTAssert(representable.emailAttachment.contentType == attachment.contentType)
        XCTAssert(representable.emailAttachment.body == attachment.body)
    }
}
