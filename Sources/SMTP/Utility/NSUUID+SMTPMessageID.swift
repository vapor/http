import Foundation

extension NSUUID {
    static var smtpMessageId: String {
        return "<" + NSUUID().uuidString + "@" + currentHostName() + ">"
    }

    // From Swift.org open source project
    //
    // Copyright (c) 2014 - 2016 Apple Inc. and the Swift project authors
    // Licensed under Apache License v2.0 with Runtime Library Exception
    //
    // See http://swift.org/LICENSE.txt for license information
    // See http://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
    //

    static internal func currentHostName() -> String {
        let hname = UnsafeMutablePointer<Int8>.allocate(capacity: Int(NI_MAXHOST))
        defer {
            hname.deinitialize()
            hname.deallocate(capacity: Int(NI_MAXHOST))
        }
        let r = gethostname(hname, Int(NI_MAXHOST))
        if r < 0 || hname[0] == 0 {
            return "localhost"
        }
        return String(cString: hname)
    }
}
