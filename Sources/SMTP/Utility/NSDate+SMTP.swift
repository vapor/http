import Foundation

extension Date {
    /*
        An SMTP formatted date string
    */
    public var smtpFormatted: String {
        return DateFormatter.sharedSMTPFormatter().string(from: self)
    }
}

extension DateFormatter {
    static func sharedSMTPFormatter() -> DateFormatter {
        struct Static {
            static let singleton: DateFormatter = .makeSMTPFormatter()
        }
        return Static.singleton
    }

    /*
         date-time       =   [ day-of-week "," ] date time [CFWS]

         day-of-week     =   ([FWS] day-name) / obs-day-of-week

         day-name        =   "Mon" / "Tue" / "Wed" / "Thu" /
         "Fri" / "Sat" / "Sun"

         date            =   day month year

         day             =   ([FWS] 1*2DIGIT FWS) / obs-day

         month           =   "Jan" / "Feb" / "Mar" / "Apr" /
         "May" / "Jun" / "Jul" / "Aug" /
         "Sep" / "Oct" / "Nov" / "Dec"

         year            =   (FWS 4*DIGIT FWS) / obs-year

         time            =   time-of-day zone

         time-of-day     =   hour ":" minute [ ":" second ]

         hour            =   2DIGIT / obs-hour

         minute          =   2DIGIT / obs-minute

         second          =   2DIGIT / obs-second

         zone            =   (FWS ( "+" / "-" ) 4DIGIT) / obs-zone
    */
    static func makeSMTPFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en-US")
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss ZZZ"
        return formatter
    }
}
