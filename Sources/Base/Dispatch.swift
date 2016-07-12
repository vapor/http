#if os(Linux)
import Strand

public func background(function: () -> Void) throws {
    let _ = try Strand(closure: function)
}
#else
import Foundation

let background = DispatchQueue.global()

public func background(function: () -> Void) throws {
    background.async(execute: function)
}
#endif
