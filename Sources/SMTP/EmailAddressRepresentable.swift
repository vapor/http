
public protocol EmailAddressRepresentable {
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
