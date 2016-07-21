/*
 
    Copyright (c) 2015 Intrepid Pursuits

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

public struct Version {
    public private(set) var major: Int = 0
    public private(set) var minor: Int = 0
    public private(set) var patch: Int = 0

    public init(major: Int, minor: Int = 0, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init(_ string: String) {
        let components = string.characters.split(separator: ".").map { String($0) }

        if components.count > 0, let major = Int(components[0]) {
            self.major = major
        }

        if components.count > 1, let minor = Int(components[1]) {
            self.minor = minor
        }

        if components.count > 2, let patch = Int(components[2]) {
            self.patch = patch
        }
    }
}

extension Version : CustomStringConvertible {
    public var description: String {
        return "\(major).\(minor).\(patch)"
    }
}

extension Version : Equatable {}

public func ==(lhs: Version, rhs: Version) -> Bool {
    guard lhs.major == rhs.major else { return false }
    guard lhs.minor == rhs.minor else { return false }
    guard lhs.patch == rhs.patch else { return false }
    return true
}

public func !=(lhs: Version, rhs: Version) -> Bool {
    return !(lhs == rhs)
}

extension Version : Comparable {}

public func < (lhs: Version, rhs: Version) -> Bool {
    if lhs.major != rhs.major {
        return lhs.major < rhs.major
    } else if lhs.minor != rhs.minor {
        return lhs.minor < rhs.minor
    } else {
        return lhs.patch < rhs.patch
    }
}

public func <= (lhs: Version, rhs: Version) -> Bool {
    return lhs < rhs || lhs == rhs
}

public func >= (lhs: Version, rhs: Version) -> Bool {
    return lhs > rhs || lhs == rhs
}

public func > (lhs: Version, rhs: Version) -> Bool {
    if lhs.major != rhs.major {
        return lhs.major > rhs.major
    } else if lhs.minor != rhs.minor {
        return lhs.minor > rhs.minor
    } else {
        return lhs.patch > rhs.patch
    }
}
