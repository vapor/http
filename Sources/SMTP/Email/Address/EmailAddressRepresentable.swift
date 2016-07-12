/*
    Allow people to conform to email address and pass directly. For example, `User` could 
    conform to EmailAddressRepresentable and they could be passed directly to arguments.
 
        Email(from: someUser, ...
*/
public protocol EmailAddressRepresentable {
    /*
        The email address that represents the object
    */
    var emailAddress: EmailAddress { get }
}

extension EmailAddress: EmailAddressRepresentable {
    public var emailAddress: EmailAddress {
        return self
    }
}

extension String: EmailAddressRepresentable {
    public var emailAddress: EmailAddress {
        return EmailAddress(name: nil, address: self)
    }
}
