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
        // Create date from components to ensure it's January 1st 1970 00:00:00 in the _local_ calendar (because that's what this test expects)
        var dateComponents = DateComponents()
        dateComponents.year = 1970
        let date = Calendar.current.date(from: dateComponents)!

        let smtpFormatted = date.smtpFormatted
        XCTAssert(smtpFormatted.hasPrefix("Thu, 1 Jan 1970 00:00:00 "))
        let suffix = smtpFormatted.components(separatedBy: "Thu, 1 Jan 1970 ").last ?? ""
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
