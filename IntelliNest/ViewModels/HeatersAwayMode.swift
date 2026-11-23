//
//  HeatersAwayMode.swift
//  IntelliNest
//

import Foundation

/// Shared rules for the heaters away mode. `restoreLead` must match the 86400 seconds in the Home Assistant
/// automation "Heaters away mode" (`automation.heaters_away_mode`).
enum HeatersAwayMode {
    static let restoreLead: TimeInterval = 24 * 60 * 60

    static func restoreAt(returnDate: Date) -> Date {
        returnDate.addingTimeInterval(-restoreLead)
    }

    /// A week from today at 16:00, a starting point the user then adjusts in the picker.
    static func defaultReturnDate(now: Date, calendar: Calendar = .current) -> Date {
        let weekAhead = calendar.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(7 * restoreLead)
        return calendar.date(bySettingHour: 16, minute: 0, second: 0, of: weekAhead) ?? weekAhead
    }

    /// The state format Home Assistant reports for a date-and-time `input_datetime`, so an optimistic
    /// update parses the same way as the next reload.
    static func stateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }
}
