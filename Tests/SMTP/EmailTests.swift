//
//  SMTPGreetingTests.swift
//  Engine
//
//  Created by Logan Wright on 7/12/16.
//
//

import XCTest
@testable import SMTP

import Foundation
import struct Base.Bytes

/*
 to /
 cc /
 bcc /
 message-id /
 in-reply-to /
 references /
 subject /
 comments /
 keywords /
 optional-field)
 */

/**
 An email message that can be sent via an SMTP Client
 */
private class Email {
    public let from: EmailAddress
    public let to: [EmailAddress]
    public let id: String = NSUUID.smtpMessageId
    public let subject: String
    #if os(Linux)
    public let date: NSDate = NSDate()
    #else
    public let date: Date = Date()
    #endif
    public var body: EmailBody
    public var attachments: [EmailAttachmentRepresentable]
    public var extendedFields: [String: String] = [:]
    public init(from: EmailAddressRepresentable, to: EmailAddressRepresentable..., subject: String, body: EmailBodyRepresentable, attachments: [EmailAttachmentRepresentable] = []) {
        self.from = from.emailAddress
        self.to = to.map { $0.emailAddress }
        self.subject = subject
        self.body = body.emailBody
        self.attachments = attachments
    }
}


class EmailTests: XCTestCase {
}
