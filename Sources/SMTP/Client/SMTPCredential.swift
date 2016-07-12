/**
    The credentials that will be used to authorize the SMTPClient with a remote host.
*/
public struct SMTPCredentials {
    /*
        The user name that will be used to authorize with host
    */
    public let user: String

    /*
        The password that will be used to authorize with host
    */
    public let pass: String

    /*
        Credentials Initializer
    */
    public init(user: String, pass: String) {
        self.user = user
        self.pass = pass
    }
}
