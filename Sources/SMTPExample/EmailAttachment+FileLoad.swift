import Foundation
import SMTP

#if Xcode
let parent = #file.characters.split(separator: "/").map(String.init).dropLast().joined(separator: "/")
let workDir = "/\(parent)/../.."
#else
let workDir = "./"
#endif

// Scraped from http://www.freeformatter.com/mime-types-list.html
let mediaTypes: [String: String] = [
    "png": "image/png",
    "pdf": "application/pdf"
    // ...
]

extension EmailAttachment {
    init?(filename: String, in directory: String) {
        guard
            let suffix = filename.components(separatedBy: ".").last,
            let mediaType = mediaTypes[suffix]
            else { return nil }
        guard let data = NSData(contentsOfFile: directory.finished(with: "/") + filename) else { return nil }
        var bytes = [UInt8](repeating: 0, count: data.length)
        data.getBytes(&bytes, length: data.length)
        self.init(filename: filename, contentType: mediaType, body: bytes)
    }
}
