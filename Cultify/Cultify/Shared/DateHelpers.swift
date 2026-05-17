import Foundation

enum DateHelpers {
    static let isoDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func isoDate(_ d: Date) -> String { isoDayFormatter.string(from: d) }
    static func date(fromISO s: String) -> Date? { isoDayFormatter.date(from: s) }

    static func startOfDay(_ d: Date) -> Date { Calendar.current.startOfDay(for: d) }

    static func headerLong(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: d)
    }

    static func weekdayShort(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: d)
    }

    static func dayNumber(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: d)
    }

    static func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f.string(from: d)
    }

    /// Reference-style stamp e.g. "16 may '26" (lowercase month, apostrophe year).
    static func rowStamp(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d MMM ''yy"
        return f.string(from: d).lowercased()
    }

    static func timeShort(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: d)
    }
}
