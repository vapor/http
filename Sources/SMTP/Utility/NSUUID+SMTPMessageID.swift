import Foundation

extension NSUUID {
    static var smtpMessageId: String {
        #if os(Linux)
        return NSUUID().UUIDString.components(separatedBy: "-").joined(separator: "")
        #else
        return NSUUID().uuidString.components(separatedBy: "-").joined(separator: "")
        #endif
    }
}
