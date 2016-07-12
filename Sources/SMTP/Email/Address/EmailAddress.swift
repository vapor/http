/*
    An email address that can be used by an SMTPClient to send emails.
*/
public struct EmailAddress {

    /*
        The display name associated with the email address. For example, jane@doe.com 
        might have the display name 'Jane D'
    */
    public let name: String?

    /*
        The underlying address associated with the account
    */
    public let address: String

    /*
        Initialize a new email address/
    */
    public init(name: String? = nil, address: String) {
        self.name = name
        self.address = address
    }
}

extension EmailAddress: Equatable {}

public func ==(lhs: EmailAddress, rhs: EmailAddress) -> Bool {
    return lhs.name == rhs.name
        && lhs.address == rhs.address
}
