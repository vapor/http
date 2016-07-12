import Foundation

#if !os(Linux)
    /*
     Temporary Foundation Naming Fix
     */
    typealias NSDateFormatter = DateFormatter
    typealias NSDate = Date
#endif

extension Date {
    /*
        An SMTP formatted date string
    */
    public var smtpFormatted: String {
        return NSDateFormatter.sharedSMTPFormatter().string(from: self)
    }
}

extension NSDateFormatter {
    static func sharedSMTPFormatter() -> NSDateFormatter {
        struct Static {
            static let singleton: NSDateFormatter = .makeSMTPFormatter()
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
    static func makeSMTPFormatter() -> NSDateFormatter {
        let formatter = NSDateFormatter()
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss ZZZ"
        return formatter
    }
}
