import Strand

public func background(function: () -> Void) throws {
    let _ = try Strand(closure: function)
}
