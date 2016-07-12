/*
    Objects that can be represented as an EmailBody
*/
public protocol EmailBodyRepresentable {
    /*
        The email body that can represent the object
    */
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
