extension Byte {
    /// '\t'
    public static let horizontalTab: Byte = 0x9

    /// '\n'
    public static let newLine: Byte = 0xA

    /// '\r'
    public static let carriageReturn: Byte = 0xD

    /// ' '
    public static let space: Byte = 0x20

    /// !
    public static let exclamation: Byte = 0x21

    /// "
    public static let quote: Byte = 0x22

    /// #
    public static let numberSign: Byte = 0x23

    /// $
    public static let dollar: Byte = 0x24

    /// %
    public static let percent: Byte = 0x25

    /// &
    public static let ampersand: Byte = 0x26

    /// '
    public static let apostrophe: Byte = 0x27

    /// (
    public static let leftParenthesis: Byte = 0x28

    /// )
    public static let rightParenthesis: Byte = 0x29

    /// *
    public static let asterisk: Byte = 0x2A

    /// +
    public static let plus: Byte = 0x2B

    /// ,
    public static let comma: Byte = 0x2C

    /// -
    public static let hyphen: Byte = 0x2D

    /// .
    public static let period: Byte = 0x2E

    /// /
    public static let forwardSlash: Byte = 0x2F

    /// 0
    public static let zero: Byte = 0x30

    /// 9
    public static let nine: Byte = 0x39

    /// :
    public static let colon: Byte = 0x3A

    /// ;
    public static let semicolon: Byte = 0x3B

    /// =
    public static let equals: Byte = 0x3D

    /// ?
    public static let questionMark: Byte = 0x3F

    /// @
    public static let at: Byte = 0x40

    /// A
    public static let A: Byte = 0x41

    /// B
    public static let B: Byte = 0x42

    /// C
    public static let C: Byte = 0x43

    /// D
    public static let D: Byte = 0x44

    /// E
    public static let E: Byte = 0x45

    /// F
    public static let F: Byte = 0x46

    /// Z
    public static let Z: Byte = 0x5A

    /// [
    public static let leftSquareBracket: Byte = 0x5B

    /// \
    public static let backSlash: Byte = 0x5C

    /// ]
    public static let rightSquareBracket: Byte = 0x5D

    /// _
    public static let underscore: Byte = 0x5F

    /// a
    public static let a: Byte = 0x61

    /// f
    public static let f: Byte = 0x66

    /// z
    public static let z: Byte = 0x7A

    /// ~
    public static let tilda: Byte = 0x7E
}

extension Byte {
    /**
        Defines the `crlf` used to denote
        line breaks in HTTP.
    */
    public static let crlf: Bytes = [
        .carriageReturn,
        .newLine
    ]
}

public func ~=(pattern: Byte, value: Byte) -> Bool {
    return pattern == value
}

extension Byte {
    public var isWhitespace: Bool {
        return self == .space || self == .newLine || self == .carriageReturn || self == .horizontalTab
    }

    public var isLetter: Bool {
        return (.a ... .z).contains(self) || (.A ... .Z).contains(self)
    }

    public var isDigit: Bool {
        return (.zero ... .nine).contains(self)
    }

    public var isAlphanumeric: Bool {
        return isLetter || isDigit
    }

    public var isHexDigit: Bool {
        return (.zero ... .nine).contains(self) || (.A ... .F).contains(self) || (.a ... .f).contains(self)
    }
}
