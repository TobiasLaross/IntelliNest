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

    /// Return times offered as one-tap choices, in days from today.
    static let presetDays = [2, 7, 14]

    /// `days` from today at 16:00, a typical time to be home again.
    static func returnDate(daysFromNow days: Int, now: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.date(byAdding: .day, value: days, to: now) ?? now.addingTimeInterval(Double(days) * restoreLead)
        return calendar.date(bySettingHour: 16, minute: 0, second: 0, of: day) ?? day
    }

    static func presetTitle(days: Int) -> String {
        switch days {
        case 7: "1 vecka"
        case 14: "2 veckor"
        default: "\(days) dagar"
        }
    }

    /// Short countdown for the home screen badge: whole days left, or hours on the last day.
    static func badge(returnDate: Date, now: Date) -> String? {
        let remaining = returnDate.timeIntervalSince(now)
        guard remaining > 0 else {
            return nil
        }
        if remaining < restoreLead {
            return "\(Int((remaining / 3600).rounded(.up))) h"
        }
        return "\(Int((remaining / restoreLead).rounded(.up))) d"
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
