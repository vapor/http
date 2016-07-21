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

#if Xcode
/*
    Structure date tests for remote server when possible
*/

class SMTPDateTests: XCTestCase {
    static let allTests = [
        ("testSMTPDate", testSMTPDate),
    ]

    func testSMTPDate() {
        let date = Date(timeIntervalSince1970: 0)
        let smtpFormatted = date.smtpFormatted
        XCTAssert(smtpFormatted.hasPrefix("Wed, 31 Dec 1969 "))
        let suffix = smtpFormatted.components(separatedBy: "Wed, 31 Dec 1969 ").last ?? ""
        let timeComps = suffix.components(separatedBy: " ")
        XCTAssert(timeComps.count == 2)

        let timeOfDay = timeComps.first ?? ""
        let hoursMinutesSecond = timeOfDay.components(separatedBy: ":")
        XCTAssert(hoursMinutesSecond.count == 3)
        hoursMinutesSecond.forEach { comp in
            // ie: 01, not just 1
            XCTAssert(comp.characters.count == 2)
        }

        let timeZone = timeComps.last ?? ""
        XCTAssert(timeZone != "")
        XCTAssert(timeZone != timeOfDay)
    }
}

#endif
