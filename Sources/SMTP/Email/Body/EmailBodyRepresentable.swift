public protocol EmailBodyRepresentable {
    var emailBody: EmailBody { get }
}

extension String: EmailBodyRepresentable {
    public var emailBody: EmailBody {
        return EmailBody(type: .plain, content: self)
    }
}

extension EmailBody: EmailBodyRepresentable {
    public var emailBody: EmailBody {
        return self
    }
}
