import Foundation

extension NSUUID {
    static var smtpMessageId: String {
        return NSUUID().uuidString
            .components(separatedBy: "-")
            .joined(separator: "")
    }
}
